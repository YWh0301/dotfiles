from __future__ import annotations

import shlex

from pyinfra import host, logger
from pyinfra.facts.pacman import PacmanPackages
from pyinfra.operations import server

from runtime import SUDO
from user_config import UserConfig


# Conservative bootstrap set used until the package profiles in
# manual/packages.md have been reviewed and explicitly enabled.
OFFICIAL_PACKAGES = {
    "archlinux-keyring",
    "git",
    "openssh",
    "python",
    "uv",
}
ARCHLINUXCN_KEYRING = "archlinuxcn-keyring"
PROXY_PACKAGES = {"dae-git", "flclash"}


def _install_command(packages: set[str], *, refresh_and_upgrade: bool) -> str:
    action = "-Syu" if refresh_and_upgrade else "-S"
    return shlex.join(["/usr/bin/pacman", action, "--needed", "--noconfirm", *sorted(packages)])


def configure_packages(settings: UserConfig) -> None:
    installed = set(host.get_fact(PacmanPackages))

    official_packages = set(OFFICIAL_PACKAGES)
    if settings.features.tailscale:
        official_packages.add("tailscale")
    if settings.features.snapper:
        official_packages.add("snapper")

    previous_transaction = None
    repositories_refreshed = False

    missing_official = official_packages - installed
    if missing_official:
        previous_transaction = server.shell(
            name="Synchronize Arch and install official bootstrap packages",
            commands=[_install_command(missing_official, refresh_and_upgrade=True)],
            _sudo=SUDO,
        )
        repositories_refreshed = True

    missing_proxy = PROXY_PACKAGES - installed
    if ARCHLINUXCN_KEYRING not in installed or missing_proxy:
        keyring_kwargs = {}
        if previous_transaction is not None:
            keyring_kwargs["_if"] = previous_transaction.did_succeed
        previous_transaction = server.shell(
            name="Install the ArchLinuxCN repository keyring",
            commands=[
                _install_command(
                    {ARCHLINUXCN_KEYRING},
                    refresh_and_upgrade=not repositories_refreshed,
                ),
            ],
            _sudo=SUDO,
            **keyring_kwargs,
        )
        repositories_refreshed = True

    if missing_proxy:
        proxy_kwargs = {}
        if previous_transaction is not None:
            proxy_kwargs["_if"] = previous_transaction.did_succeed
        server.shell(
            name="Install proxy frontends from ArchLinuxCN",
            commands=[
                _install_command(
                    missing_proxy,
                    refresh_and_upgrade=not repositories_refreshed,
                ),
            ],
            _sudo=SUDO,
            **proxy_kwargs,
        )

    if settings.features.localsend:
        logger.warning(
            "LocalSend is enabled but localsend-bin is not in the configured pacman repositories; "
            "AUR/private-repository installation remains a second-stage task.",
        )
