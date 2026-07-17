from __future__ import annotations

from pathlib import Path
import shlex
import subprocess

from pyinfra import logger
from pyinfra.operations import server

from package_selection import PackageSelection
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


def configure_external_packages(
    settings: UserConfig,
    selection: PackageSelection,
) -> None:
    selected = set(selection.external_builds)
    unknown = selected - set(BUILD_ORDER)
    if unknown:
        raise RuntimeError(
            "selected external packages have no reviewed build order: "
            + ", ".join(sorted(unknown)),
        )

    missing_deferred = {
        package for package in selection.deferred_aur if _installed_version(package) is None
    }
    if missing_deferred:
        logger.warning(
            "Selected profile AUR packages require separate review and remain deferred: %s",
            ", ".join(sorted(missing_deferred)),
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

    build_helper = Path(__file__).resolve().parents[1] / "files/scripts/build-external-with-dae"
    for package, directory, desired in builds:
        server.shell(
            name=f"Build and install reviewed external package {package} {desired}",
            commands=[shlex.join([str(build_helper), package])],
            _chdir=str(directory),
            _env=environment,
        )
