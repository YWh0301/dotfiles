from __future__ import annotations

from pathlib import Path

from pyinfra.operations import server

from runtime import SUDO


def _has_fstab_entries(path: Path = Path("/etc/fstab")) -> bool:
    return path.is_file() and any(
        line.strip() and not line.lstrip().startswith("#")
        for line in path.read_text(encoding="utf-8").splitlines()
    )


def configure_filesystem() -> None:
    if _has_fstab_entries():
        return
    fstab = server.shell(
        name="Generate the persistent filesystem table",
        commands=["/usr/bin/genfstab -U / > /etc/fstab"],
        _sudo=SUDO,
    )
    server.shell(
        name="Validate the generated filesystem table",
        commands=["/usr/bin/findmnt --verify --tab-file /etc/fstab"],
        _sudo=SUDO,
        _if=fstab.did_change,
    )
