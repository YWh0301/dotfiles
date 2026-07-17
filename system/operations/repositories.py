from __future__ import annotations

from pyinfra.operations import files

from runtime import SUDO
from user_config import UserConfig


def configure_repositories(settings: UserConfig) -> None:
    files.template(
        name="Install the managed Arch mirror list",
        src="files/pacman/mirrorlist.j2",
        dest="/etc/pacman.d/mirrorlist",
        user="root",
        group="root",
        mode="644",
        arch_mirrors=settings.mirrors.arch,
        _sudo=SUDO,
    )
    files.template(
        name="Install managed Pacman repositories and options",
        src="files/pacman/pacman.conf.j2",
        dest="/etc/pacman.conf",
        user="root",
        group="root",
        mode="644",
        repositories=settings.pacman.repositories,
        parallel_downloads=settings.pacman.parallel_downloads,
        archlinuxcn_mirrors=settings.mirrors.archlinuxcn,
        proaudio_mirrors=settings.mirrors.proaudio,
        _sudo=SUDO,
    )
