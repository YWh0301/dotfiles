from __future__ import annotations

import shlex
import subprocess

from pyinfra import logger
from pyinfra.operations import server

from package_selection import PackageSelection
from runtime import IS_CHROOT, SUDO


ARCHLINUXCN_KEYRING = "archlinuxcn-keyring"
NVIDIA_MODULE_PACKAGES = {
    "nvidia",
    "nvidia-dkms",
    "nvidia-lts",
    "nvidia-open",
    "nvidia-open-dkms",
    "nvidia-open-lts",
}
KNOWN_PACKAGE_TRANSITIONS = {
    "exfatprogs": "exfat-utils",
    "pandoc-bin": "pandoc-cli",
}


def _install_command(
    packages: set[str],
    *,
    refresh_and_upgrade: bool,
    accept_known_conflict: bool = False,
) -> str:
    action = "-Syu" if refresh_and_upgrade else "-S"
    arguments = ["/usr/bin/pacman", action, "--needed", "--noconfirm"]
    if accept_known_conflict:
        # ALPM conflict-question bit. This is limited to the explicitly detected
        # NVIDIA module-family transition below, never enabled globally.
        arguments.extend(["--ask", "4"])
    return shlex.join([*arguments, *sorted(packages)])


def _installed(packages: set[str]) -> set[str]:
    return {
        package
        for package in packages
        if subprocess.run(
            ["/usr/bin/pacman", "-Q", package],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    }


def _synchronized_groups(candidates: set[str]) -> dict[str, set[str]]:
    group_names = set(
        subprocess.check_output(["/usr/bin/pacman", "-Sg"], text=True).splitlines(),
    )
    groups: dict[str, set[str]] = {}
    for group in candidates & group_names:
        output = subprocess.check_output(["/usr/bin/pacman", "-Sg", group], text=True)
        groups[group] = {line.split(maxsplit=1)[1] for line in output.splitlines()}
    return groups


def _pacman_unmet(dependencies: set[str]) -> set[str]:
    if not dependencies:
        return set()
    result = subprocess.run(
        ["/usr/bin/pacman", "-T", *sorted(dependencies)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode not in {0, 127}:
        raise RuntimeError(f"pacman dependency check failed: {result.stderr.strip()}")
    return set(result.stdout.splitlines())


def _unmet_packages(packages: set[str], groups: dict[str, set[str]]) -> set[str]:
    # pacman -T understands virtual providers, but package groups are not
    # dependency names. A group is satisfied only when all of its members are.
    ordinary = packages - set(groups)
    unmet = _pacman_unmet(ordinary)
    for group in packages & set(groups):
        if _pacman_unmet(groups[group]):
            unmet.add(group)
    return unmet


def _synchronized_package_names(groups: dict[str, set[str]]) -> set[str]:
    output = subprocess.check_output(["/usr/bin/pacman", "-Slq"], text=True)
    return set(output.splitlines()) | set(groups)


def configure_packages(selection: PackageSelection):
    pacman_packages = set(selection.pacman)
    logger.info(
        "Package manifest selected %d pacman, %d AUR, and %d myPKGBUILDS packages; "
        "profiles: %s; hardware: %s",
        len(selection.pacman),
        len(selection.aur),
        len(selection.mypkgbuilds),
        ", ".join(sorted(selection.profiles)) or "none",
        ", ".join(sorted(selection.hardware)) or "none",
    )

    groups = _synchronized_groups(pacman_packages)
    missing = _unmet_packages(pacman_packages, groups)
    synchronized = _synchronized_package_names(groups)
    unavailable = missing - synchronized
    if unavailable and not IS_CHROOT:
        raise RuntimeError(
            "selected packages are unavailable from configured pacman repositories: "
            + ", ".join(sorted(unavailable)),
        )
    # A fresh chroot is planned against the pacstrap repository database, before
    # the managed ArchLinuxCN/Pro Audio config and databases exist. Pacman will
    # resolve the full selected set after the first -Syu operation.
    installable = missing if IS_CHROOT else missing & synchronized

    package_change = None
    if installable:
        logger.info(
            "Missing selected pacman packages (%d): %s",
            len(installable),
            ", ".join(sorted(installable)),
        )
        keyring = server.shell(
            name="Upgrade the system and refresh the ArchLinuxCN keyring",
            commands=[_install_command({ARCHLINUXCN_KEYRING}, refresh_and_upgrade=True)],
            _sudo=SUDO,
        )
        remaining = installable - {ARCHLINUXCN_KEYRING}
        prerequisite = keyring

        # Scope conflict acceptance to one reviewed replacement at a time; the
        # main transaction can never approve unrelated removals silently.
        installed_obsolete = _installed(set(KNOWN_PACKAGE_TRANSITIONS.values()))
        for replacement, obsolete in KNOWN_PACKAGE_TRANSITIONS.items():
            if replacement not in remaining or obsolete not in installed_obsolete:
                continue
            previous = prerequisite
            prerequisite = server.shell(
                name=f"Replace obsolete {obsolete} with {replacement}",
                commands=[
                    _install_command(
                        {replacement},
                        refresh_and_upgrade=False,
                        accept_known_conflict=True,
                    ),
                ],
                _sudo=SUDO,
                _if=previous.did_succeed,
            )
            remaining.remove(replacement)

        if remaining:
            selected_nvidia = pacman_packages & NVIDIA_MODULE_PACKAGES
            if len(selected_nvidia) > 1:
                raise RuntimeError(
                    "multiple NVIDIA kernel module variants selected: "
                    + ", ".join(sorted(selected_nvidia)),
                )
            installed_nvidia = _installed(NVIDIA_MODULE_PACKAGES)
            nvidia_transition = bool(
                selected_nvidia
                and installed_nvidia
                and not selected_nvidia <= installed_nvidia
            )
            if nvidia_transition:
                logger.warning(
                    "Kernel selection requires an NVIDIA module transition: %s -> %s",
                    ", ".join(sorted(installed_nvidia)),
                    ", ".join(sorted(selected_nvidia)),
                )
            package_change = server.shell(
                name=(
                    "Install selected packages and switch the NVIDIA module family"
                    if nvidia_transition
                    else "Install packages selected by manual/packages.md"
                ),
                commands=[
                    _install_command(
                        remaining,
                        refresh_and_upgrade=False,
                        accept_known_conflict=nvidia_transition,
                    ),
                ],
                _sudo=SUDO,
                _if=prerequisite.did_succeed,
            )
        else:
            package_change = prerequisite

    return package_change
