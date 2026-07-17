from __future__ import annotations

from pathlib import Path
import subprocess

from pyinfra.operations import server
from pyinfra.operations.util import any_changed

from runtime import IS_CHROOT, SUDO


GRUB_EFI_BINARY = Path("/boot/EFI/GRUB/grubx64.efi")
GRUB_CONFIG = Path("/boot/grub/grub.cfg")


def configure_bootloader(package_change=None) -> None:
    if not IS_CHROOT:
        return
    if not Path("/sys/firmware/efi/efivars").is_dir():
        raise RuntimeError("GRUB bootstrap requires the ArchISO to be booted in UEFI mode")
    boot_filesystem = subprocess.run(
        ["/usr/bin/findmnt", "--noheadings", "--output", "FSTYPE", "/boot"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if boot_filesystem not in {"vfat", "fat", "fat32"}:
        raise RuntimeError(f"/boot must be the mounted EFI System Partition, got {boot_filesystem!r}")

    grub_install = None
    if not GRUB_EFI_BINARY.is_file():
        grub_install = server.shell(
            name="Install GRUB into the mounted EFI System Partition",
            commands=[
                "/usr/bin/grub-install --target=x86_64-efi --efi-directory=/boot "
                "--bootloader-id=GRUB --recheck",
            ],
            _sudo=SUDO,
        )

    triggers = [operation for operation in (package_change, grub_install) if operation is not None]
    if triggers or not GRUB_CONFIG.is_file():
        kwargs = {"_if": any_changed(*triggers)} if triggers and GRUB_CONFIG.is_file() else {}
        grub_config = server.shell(
            name="Generate the GRUB boot menu",
            commands=["/usr/bin/grub-mkconfig -o /boot/grub/grub.cfg"],
            _sudo=SUDO,
            **kwargs,
        )
        server.shell(
            name="Validate the generated GRUB configuration",
            commands=["/usr/bin/grub-script-check /boot/grub/grub.cfg"],
            _sudo=SUDO,
            _if=grub_config.did_succeed,
        )
