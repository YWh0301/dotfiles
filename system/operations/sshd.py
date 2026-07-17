from __future__ import annotations

from datetime import datetime
from io import StringIO
from pathlib import Path
import getpass
import re
import subprocess

from pyinfra.operations import files, server, systemd
from pyinfra.operations.util import any_changed

from runtime import SUDO
from user_config import UserConfig


CA_SOURCE = Path.home() / ".local/share/ssh-ca/user_ca.pub"
CA_DESTINATION = "/etc/ssh/trusted-user-ca-keys.pem"
PRINCIPALS_DIRECTORY = "/etc/ssh/auth-principals"
DROPIN = "/etc/ssh/sshd_config.d/90-personal-user-ca.conf"
PUBLIC_KEY = Path.home() / ".ssh/id_ed25519.pub"
CERTIFICATE = Path.home() / ".ssh/id_ed25519-cert.pub"


def _fingerprint(path: Path) -> str:
    output = subprocess.check_output(["/usr/bin/ssh-keygen", "-lf", str(path)], text=True)
    return output.split()[1]


def _validate_local_certificate(principal: str) -> None:
    for path in (CA_SOURCE, PUBLIC_KEY, CERTIFICATE):
        if not path.is_file():
            raise RuntimeError(f"CA-only sshd requires the local SSH file: {path}")

    text = subprocess.check_output(
        ["/usr/bin/ssh-keygen", "-L", "-f", str(CERTIFICATE)],
        text=True,
    )
    public_match = re.search(r"^\s*Public key:.*(SHA256:[^ ]+)$", text, re.MULTILINE)
    ca_match = re.search(r"^\s*Signing CA:.*(SHA256:[^ ]+)", text, re.MULTILINE)
    valid_match = re.search(r"^\s*Valid: from ([^ ]+) to ([^ ]+)$", text, re.MULTILINE)
    principals_match = re.search(
        r"^\s*Principals:\s*$\n(?P<body>.*?)(?=^\s*Critical Options:)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not all((public_match, ca_match, valid_match, principals_match)):
        raise RuntimeError(f"Could not parse SSH certificate: {CERTIFICATE}")

    principals = {
        line.strip() for line in principals_match.group("body").splitlines() if line.strip()
    }
    expires = datetime.fromisoformat(valid_match.group(2))
    if public_match.group(1) != _fingerprint(PUBLIC_KEY):
        raise RuntimeError("SSH certificate does not match the local public key")
    if ca_match.group(1) != _fingerprint(CA_SOURCE):
        raise RuntimeError("SSH certificate was not signed by the configured User CA")
    if principal not in principals:
        raise RuntimeError(f"SSH certificate does not contain principal {principal!r}")
    if expires <= datetime.now():
        raise RuntimeError("SSH certificate has expired; run chezmoi apply to renew it")


def configure_sshd(settings: UserConfig) -> None:
    if not settings.features.sshd:
        systemd.service(
            name="Disable the OpenSSH daemon",
            service="sshd.service",
            running=False,
            enabled=False,
            _sudo=SUDO,
        )
        return

    if not CA_SOURCE.is_file():
        raise RuntimeError(
            f"SSH server is enabled but the User CA public key is missing: {CA_SOURCE}. "
            "Run chezmoi apply and complete CA enrollment first.",
        )

    principal = getpass.getuser()
    _validate_local_certificate(principal)

    principals_directory = files.directory(
        name="Create the SSH authorized-principals directory",
        path=PRINCIPALS_DIRECTORY,
        user="root",
        group="root",
        mode="755",
        _sudo=SUDO,
    )
    ca_key = files.put(
        name="Install the trusted SSH User CA public key",
        src=str(CA_SOURCE),
        dest=CA_DESTINATION,
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    principal_file = files.put(
        name="Install the SSH principal for the local user",
        src=StringIO(f"{principal}\n"),
        dest=f"{PRINCIPALS_DIRECTORY}/{principal}",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    dropin = files.template(
        name="Install the CA-only sshd drop-in",
        src="files/sshd/90-personal-user-ca.conf.j2",
        dest=DROPIN,
        user="root",
        group="root",
        mode="644",
        sshd_port=settings.sshd.port,
        _sudo=SUDO,
    )

    ssh_files_changed = any_changed(principals_directory, ca_key, principal_file, dropin)
    validation = server.shell(
        name="Validate sshd configuration after trust changes",
        commands=["/usr/bin/sshd -t"],
        _sudo=SUDO,
        _if=ssh_files_changed,
    )

    service = systemd.service(
        name="Enable and start the OpenSSH daemon",
        service="sshd.service",
        running=True,
        enabled=True,
        _sudo=SUDO,
    )
    systemd.service(
        name="Reload OpenSSH after validated configuration changes",
        service="sshd.service",
        reloaded=True,
        _sudo=SUDO,
        _if=[ssh_files_changed, validation.did_succeed, service.did_succeed],
    )
