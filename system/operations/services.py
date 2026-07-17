from __future__ import annotations

from pyinfra.operations import systemd

from runtime import SUDO
from user_config import UserConfig


def configure_services(settings: UserConfig) -> None:
    systemd.service(
        name="Converge Tailscale service",
        service="tailscaled.service",
        running=settings.features.tailscale,
        enabled=settings.features.tailscale,
        _sudo=SUDO,
    )
