from __future__ import annotations

from pathlib import Path
import re
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
BUILD_DEPENDENCIES = {
    "python-pdfplumber": ("python-pypdfium2",),
    "pi-ext-pdf": ("python-pdfplumber",),
}
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


def _srcinfo_build_dependencies(directory: Path) -> frozenset[str]:
    dependencies: set[str] = set()
    for line in (directory / ".SRCINFO").read_text(encoding="utf-8").splitlines():
        if " = " not in line:
            continue
        key, value = (part.strip() for part in line.split(" = ", 1))
        base_key = key.split("_", 1)[0]
        if base_key not in {"makedepends", "checkdepends"}:
            continue
        name = re.split(r"[<>=]", value, maxsplit=1)[0].strip()
        if name:
            dependencies.add(name)
    return frozenset(dependencies)


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


def _build_dependency_cleanup_command(
    packages: list[str],
    failure_files: list[Path],
) -> str:
    failed_test = " || ".join(
        f"test -s {shlex.quote(str(path))}" for path in failure_files
    ) or "false"
    parts = [
        f"if {failed_test}; then "
        "/usr/bin/printf '%s\\n' "
        "'WARNING: skipping external build dependency cleanup because a build failed' >&2; "
        "else",
        "orphans=$(/usr/bin/pacman -Qdtq 2>/dev/null || true)",
        "set --",
        *(
            f"if /usr/bin/printf '%s\\n' \"${{orphans}}\" | "
            f"/usr/bin/grep -Fqx -- {shlex.quote(package)}; then "
            f"set -- \"$@\" {shlex.quote(package)}; fi"
            for package in packages
        ),
        "if test \"$#\" -gt 0; then "
        "/usr/bin/printf 'Removing external build dependencies: %s\\n' \"$*\"; "
        "sudo -n /usr/bin/pacman -Rns --noconfirm -- \"$@\"; "
        "else /usr/bin/printf '%s\\n' 'No orphaned external build dependencies to remove'; fi",
        "fi",
    ]
    return "\n".join(parts)


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
    order = {package: index for index, package in enumerate(BUILD_ORDER)}
    for package, dependencies in BUILD_DEPENDENCIES.items():
        if package not in selected:
            continue
        invalid = [
            dependency
            for dependency in dependencies
            if dependency not in selected or order[dependency] >= order[package]
        ]
        if invalid:
            raise RuntimeError(
                f"reviewed dependencies for {package} must be selected and ordered first: "
                + ", ".join(invalid),
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
    build_dependencies: set[str] = set()
    for package in BUILD_ORDER:
        if package not in selected:
            continue
        directory = PKGBUILDS_ROOT / package
        if not (directory / "PKGBUILD").is_file() or not (directory / ".SRCINFO").is_file():
            raise RuntimeError(f"reviewed vendored PKGBUILD is missing for {package}: {directory}")
        if any(directory.rglob(".git")):
            raise RuntimeError(f"nested Git metadata is forbidden in vendored PKGBUILD: {directory}")
        desired = _srcinfo_version(directory)
        build_dependencies.update(_srcinfo_build_dependencies(directory))
        if _needs_build(package, desired):
            builds.append((package, directory, desired))

    if builds:
        logger.info(
            "External packages to build in reviewed order: %s",
            ", ".join(f"{name}={version}" for name, _, version in builds),
        )
    status_dir = Path.home() / ".cache/personal-system/makepkg/status"
    failure_files = [status_dir / f"{package}.failure" for package, _, _ in builds]
    if builds:
        makepkg_config = Path(__file__).resolve().parents[1] / "files/makepkg/noninteractive.conf"
        base_environment = {
            "MAKEPKG_CONFIG": str(makepkg_config),
            "STATUSDIR": str(status_dir),
            "BUILDDIR": str(Path.home() / ".cache/personal-system/makepkg/build"),
            "LOGDEST": str(Path.home() / ".cache/personal-system/makepkg/logs"),
            "PKGDEST": str(Path.home() / ".cache/personal-system/makepkg/packages"),
            "SRCDEST": str(Path.home() / ".cache/personal-system/makepkg/sources"),
        }
        if settings.proxy.backend == "flclash" and not IS_CHROOT:
            proxy = f"http://127.0.0.1:{settings.proxy.flclash_http_port}"
            base_environment.update(
                http_proxy=proxy,
                https_proxy=proxy,
                HTTP_PROXY=proxy,
                HTTPS_PROXY=proxy,
            )

        build_helper = Path(__file__).resolve().parents[1] / "files/scripts/build-external-with-dae"
        server.shell(
            name="Clear current external package build status",
            commands=[shlex.join(["/usr/bin/rm", "-f", "--", *(str(path) for path in failure_files)])],
        )
        for package, directory, desired in builds:
            failure_file = status_dir / f"{package}.failure"
            environment = dict(base_environment)
            environment["REQUIRED_EXTERNAL_DEPENDENCIES"] = " ".join(
                BUILD_DEPENDENCIES.get(package, ()),
            )
            helper_command = shlex.join([str(build_helper), package])
            unexpected_message = f"unexpected build helper exit for {package}"
            command = (
                f"{helper_command} || {{ "
                f"status=$?; /usr/bin/install -d {shlex.quote(str(status_dir))}; "
                f"if ! test -s {shlex.quote(str(failure_file))}; then "
                f"/usr/bin/printf '%s\\n' {shlex.quote(unexpected_message)} "
                f"> {shlex.quote(str(failure_file))}; fi; "
                f"/usr/bin/printf 'WARNING: %s; continuing deployment\\n' "
                f"\"$(cat {shlex.quote(str(failure_file))})\" >&2; "
                f"exit \"${{status}}\"; }}"
            )
            server.shell(
                name=f"Build and install reviewed external package {package} {desired}",
                commands=[command],
                _chdir=str(directory),
                _env=environment,
                _ignore_errors=True,
            )

        report_parts = [
            "failures=0",
            *(
                f"if test -s {shlex.quote(str(path))}; then "
                f"failures=1; /usr/bin/printf 'WARNING: external package %s failed: %s\\n' "
                f"{shlex.quote(package)} \"$(cat {shlex.quote(str(path))})\" >&2; fi"
                for (package, _, _), path in zip(builds, failure_files, strict=True)
            ),
            "if test \"${failures}\" -eq 0; then "
            "/usr/bin/printf '%s\\n' 'All requested external packages were installed successfully'; "
            "else /usr/bin/printf '%s\\n' "
            "'WARNING: one or more external packages failed; deployment continued' >&2; fi",
        ]
        server.shell(
            name="Report external package build results",
            commands=["; ".join(report_parts)],
        )

    protected = set(selection.pacman) | selected
    cleanup_candidates = sorted(build_dependencies - protected)
    if not builds:
        orphaned = set(
            subprocess.run(
                ["/usr/bin/pacman", "-Qdtq"],
                check=False,
                capture_output=True,
                text=True,
            ).stdout.splitlines(),
        )
        cleanup_candidates = [name for name in cleanup_candidates if name in orphaned]
    if not cleanup_candidates:
        return

    server.shell(
        name="Remove orphaned external package build dependencies after successful builds",
        commands=[_build_dependency_cleanup_command(cleanup_candidates, failure_files)],
        _ignore_errors=True,
    )
