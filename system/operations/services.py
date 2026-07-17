from __future__ import annotations

from pyinfra.operations import files, server, systemd

from hardware import detect_hardware_selectors
from runtime import IS_CHROOT, SUDO
from user_config import UserConfig


def _system_service(*, name: str, service: str, enabled: bool = True) -> None:
    systemd.service(
        name=name,
        service=service,
        running=None if IS_CHROOT else enabled,
        enabled=enabled,
        _sudo=SUDO,
    )


def _configure_pipewire_user_units() -> None:
    # These global user-unit links are consumed when the user's systemd manager
    # starts. They require neither a user bus nor a running target system in the
    # installation chroot.
    for directory in (
        "/etc/systemd/user/sockets.target.wants",
        "/etc/systemd/user/pipewire.service.wants",
    ):
        files.directory(
            name=f"Create global user-unit directory {directory}",
            path=directory,
            user="root",
            group="root",
            mode="755",
            _sudo=SUDO,
        )
    for path, target in (
        (
            "/etc/systemd/user/sockets.target.wants/pipewire.socket",
            "/usr/lib/systemd/user/pipewire.socket",
        ),
        (
            "/etc/systemd/user/sockets.target.wants/pipewire-pulse.socket",
            "/usr/lib/systemd/user/pipewire-pulse.socket",
        ),
        (
            "/etc/systemd/user/pipewire.service.wants/wireplumber.service",
            "/usr/lib/systemd/user/wireplumber.service",
        ),
        (
            "/etc/systemd/user/pipewire-session-manager.service",
            "/usr/lib/systemd/user/wireplumber.service",
        ),
    ):
        files.link(
            name=f"Enable user audio unit {path.rsplit('/', 1)[-1]}",
            path=path,
            target=target,
            symbolic=True,
            force=True,
            _sudo=SUDO,
        )


def _configure_laptop_power_services(settings: UserConfig) -> None:
    if settings.machine.kind != "laptop":
        return

    unit = files.template(
        name="Install the powertop auto-tune service",
        src="files/systemd/powertop-autotune.service.j2",
        dest="/etc/systemd/system/powertop-autotune.service",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    server.shell(
        name="Reload systemd after installing the powertop unit",
        commands=["/usr/bin/systemctl daemon-reload"],
        _sudo=SUDO,
        _if=unit.did_change,
    )
    _system_service(
        name="Enable powertop automatic tuning",
        service="powertop-autotune.service",
    )
    _system_service(
        name="Enable automatic CPU frequency management",
        service="auto-cpufreq.service",
    )
    if "cpu_intel" in detect_hardware_selectors():
        _system_service(
            name="Enable Intel thermal management",
            service="thermald.service",
        )


def configure_services(settings: UserConfig) -> None:
    _system_service(name="Enable NetworkManager", service="NetworkManager.service")
    _system_service(name="Enable system time synchronization", service="systemd-timesyncd.service")
    _system_service(name="Enable Bluetooth", service="bluetooth.service")
    _system_service(name="Enable CUPS printing", service="cups.service")
    _system_service(name="Enable periodic SSD trimming", service="fstrim.timer")
    _system_service(name="Enable periodic Pacman cache cleanup", service="paccache.timer")
    _system_service(name="Enable periodic manual-page index updates", service="man-db.timer")
    _system_service(
        name="Converge Tailscale service",
        service="tailscaled.service",
        enabled=settings.features.tailscale,
    )
    _configure_pipewire_user_units()
    _configure_laptop_power_services(settings)
