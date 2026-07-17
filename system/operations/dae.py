from __future__ import annotations

from pathlib import Path
import subprocess

from pyinfra.operations import files, server, systemd

from runtime import SUDO
from user_config import UserConfig


DAE_SOURCE = Path.home() / ".config/reference/dae/config.dae"
DAE_DESTINATION = "/etc/dae/config.dae"


def configure_dae(settings: UserConfig) -> None:
    if not DAE_SOURCE.is_file():
        raise RuntimeError(
            f"DAE configuration is missing: {DAE_SOURCE}. Run chezmoi apply first.",
        )

    # Reject a broken rendered user configuration before replacing the last
    # known-good system copy. The post-install check additionally verifies the
    # final path with its system ownership and mode.
    subprocess.run(
        ["/usr/bin/dae", "validate", "-c", str(DAE_SOURCE)],
        check=True,
    )

    files.directory(
        name="Create the DAE configuration directory",
        path="/etc/dae",
        user="root",
        group="root",
        mode="755",
        _sudo=SUDO,
    )
    dae_config = files.put(
        name="Install the rendered DAE configuration",
        src=str(DAE_SOURCE),
        dest=DAE_DESTINATION,
        user="root",
        group="wheel",
        mode="640",
        _sudo=SUDO,
    )
    validation = server.shell(
        name="Validate DAE configuration after changes",
        commands=[f"/usr/bin/dae validate -c {DAE_DESTINATION}"],
        _sudo=SUDO,
        _if=dae_config.did_change,
    )

    dae_active = settings.proxy.backend == "dae"
    service = systemd.service(
        name="Converge DAE transparent-proxy service",
        service="dae.service",
        running=dae_active,
        enabled=dae_active,
        _sudo=SUDO,
        _if=validation.did_succeed,
    )
    if dae_active:
        systemd.service(
            name="Reload DAE after validated configuration changes",
            service="dae.service",
            reloaded=True,
            _sudo=SUDO,
            _if=[dae_config.did_change, validation.did_succeed, service.did_succeed],
        )
