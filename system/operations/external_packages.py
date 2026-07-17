from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
import shlex
import subprocess

from pyinfra import logger
from pyinfra.operations import server

from hardware import detect_hardware_selectors
from package_manifest import parse_package_document, select_packages
from runtime import IS_CHROOT
from user_config import UserConfig


PKGBUILDS_ROOT = Path(__file__).resolve().parents[2] / "pkgbuilds"
# Explicit order is a security and dependency boundary. Newly selected external
# packages fail closed until their PKGBUILD is reviewed and placed here.
BUILD_ORDER = (
    "antigen",
    "localsend-bin",
    "pcloud-drive",
    "nvim-lazy",
    "vivify",
    "pi-coding-agent",
    "pi-ext-web-access",
    "python-pypdfium2",
    "python-pdfplumber",
    "agent-browser-bin",
    "pi-ext-pdf",
    "pi-ext-agent-browser-native",
)


def _srcinfo_version(directory: Path) -> str:
    values: dict[str, str] = {}
    for line in (directory / ".SRCINFO").read_text(encoding="utf-8").splitlines():
        if " = " not in line:
            continue
        key, value = (part.strip() for part in line.split(" = ", 1))
        if key in {"epoch", "pkgver", "pkgrel"} and key not in values:
            values[key] = value
    if not {"pkgver", "pkgrel"} <= set(values):
        raise ValueError(f"invalid .SRCINFO version in {directory}")
    version = f"{values['pkgver']}-{values['pkgrel']}"
    return f"{values['epoch']}:{version}" if values.get("epoch") else version


def _installed_version(package: str) -> str | None:
    result = subprocess.run(
        ["/usr/bin/pacman", "-Q", package],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout.split(maxsplit=1)[1].strip()


def _needs_build(package: str, desired: str) -> bool:
    installed = _installed_version(package)
    if installed is None:
        return True
    comparison = int(
        subprocess.check_output(["/usr/bin/vercmp", installed, desired], text=True).strip(),
    )
    if comparison > 0:
        logger.warning(
            "Installed external package %s (%s) is newer than vendored PKGBUILD (%s); keeping it",
            package,
            installed,
            desired,
        )
    return comparison < 0


def configure_external_packages(settings: UserConfig) -> None:
    entries = parse_package_document()
    hardware = detect_hardware_selectors()
    _, _, selected_mypkgbuilds, _ = select_packages(
        entries,
        machine_kind=settings.machine.kind,
        features=asdict(settings.features),
        hardware=hardware,
        profiles=set(settings.packages.profiles),
    )
    always_aur = {
        entry.name
        for entry in entries
        if entry.repository == "aur" and entry.selector == "always"
    }
    selected = always_aur | selected_mypkgbuilds

    unknown = selected - set(BUILD_ORDER)
    if unknown:
        raise RuntimeError(
            "selected external packages have no reviewed build order: "
            + ", ".join(sorted(unknown)),
        )

    builds: list[tuple[str, Path, str]] = []
    for package in BUILD_ORDER:
        if package not in selected:
            continue
        directory = PKGBUILDS_ROOT / package
        if not (directory / "PKGBUILD").is_file() or not (directory / ".SRCINFO").is_file():
            raise RuntimeError(f"reviewed vendored PKGBUILD is missing for {package}: {directory}")
        if any(directory.rglob(".git")):
            raise RuntimeError(f"nested Git metadata is forbidden in vendored PKGBUILD: {directory}")
        desired = _srcinfo_version(directory)
        if _needs_build(package, desired):
            builds.append((package, directory, desired))

    if not builds:
        return

    logger.info(
        "External packages to build in reviewed order: %s",
        ", ".join(f"{name}={version}" for name, _, version in builds),
    )
    environment = {
        "BUILDDIR": str(Path.home() / ".cache/personal-system/makepkg/build"),
        "LOGDEST": str(Path.home() / ".cache/personal-system/makepkg/logs"),
        "PKGDEST": str(Path.home() / ".cache/personal-system/makepkg/packages"),
        "SRCDEST": str(Path.home() / ".cache/personal-system/makepkg/sources"),
    }
    if settings.proxy.backend == "flclash" and not IS_CHROOT:
        proxy = f"http://127.0.0.1:{settings.proxy.flclash_http_port}"
        environment.update(
            http_proxy=proxy,
            https_proxy=proxy,
            HTTP_PROXY=proxy,
            HTTPS_PROXY=proxy,
        )

    cache_directories = [environment[key] for key in ("BUILDDIR", "LOGDEST", "PKGDEST", "SRCDEST")]
    prepare_cache = shlex.join(["/usr/bin/install", "-d", *cache_directories])
    build_command = shlex.join(
        [
            "/usr/bin/makepkg",
            "--syncdeps",
            "--install",
            "--needed",
            "--noconfirm",
            "--cleanbuild",
            "--clean",
        ],
    )
    dae_config = "/etc/dae/config.dae"
    for package, directory, desired in builds:
        # External source availability must never make the signed base-system
        # transaction unusable. Try the selected normal path first. If it
        # fails, retry without explicit proxy variables through the already
        # validated DAE config, starting a temporary foreground DAE when the
        # normal service is unavailable (as in arch-chroot). A final failure is
        # deliberately reported but exits successfully; the next apply retries.
        script = f"""
set +e
{prepare_cache}
{build_command}
status=$?
if [ "$status" -eq 0 ]; then
    exit 0
fi
printf '%s\\n' 'WARNING: direct/selected-proxy build failed for {package}; trying DAE fallback' >&2
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
if ! sudo -n /usr/bin/dae validate -c {dae_config} >/dev/null 2>&1; then
    printf '%s\\n' 'WARNING: DAE is unavailable or invalid; deferring {package}' >&2
    exit 0
fi
started_dae=0
dae_pid=''
dae_launcher=''
cleanup_dae() {{
    if [ "$started_dae" -eq 1 ]; then
        if [ -n "$dae_pid" ]; then
            sudo -n /usr/bin/kill "$dae_pid" >/dev/null 2>&1 || true
        elif [ -n "$dae_launcher" ]; then
            /usr/bin/kill "$dae_launcher" >/dev/null 2>&1 || true
        fi
        [ -z "$dae_launcher" ] || wait "$dae_launcher" >/dev/null 2>&1 || true
        sudo -n /usr/bin/rm -f /run/dae.pid
        started_dae=0
    fi
}}
trap cleanup_dae EXIT INT TERM
if ! sudo -n /usr/bin/systemctl is-active --quiet dae.service 2>/dev/null; then
    sudo -n /usr/bin/rm -f /run/dae.pid
    sudo -n /usr/bin/dae run -c {dae_config} --disable-sudo \\
        --logfile /tmp/personal-system-dae.log >/dev/null 2>&1 &
    dae_launcher=$!
    started_dae=1
    for _ in $(seq 1 20); do
        /usr/bin/curl --fail --silent --location --head --max-time 3 \\
            https://aur.archlinux.org/ >/dev/null 2>&1 && break
        sleep 1
    done
    if sudo -n /usr/bin/test -s /run/dae.pid; then
        dae_pid=$(sudo -n /usr/bin/cat /run/dae.pid)
    fi
fi
{build_command}
status=$?
cleanup_dae
trap - EXIT INT TERM
if [ "$status" -ne 0 ]; then
    printf '%s\\n' 'WARNING: DAE fallback also failed; deferring {package} until a later apply' >&2
fi
exit 0
""".strip()
        server.shell(
            name=f"Build and install reviewed external package {package} {desired}",
            commands=[shlex.join(["/usr/bin/bash", "-c", script])],
            _chdir=str(directory),
            _env=environment,
        )
