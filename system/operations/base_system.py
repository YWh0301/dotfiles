from __future__ import annotations

from io import StringIO
from pathlib import Path
import getpass

from pyinfra.operations import files, server
from pyinfra.operations.util import any_changed

from runtime import SUDO
from user_config import UserConfig


def configure_base_system(settings: UserConfig) -> None:
    fstab_path = Path("/etc/fstab")
    fstab_configured = fstab_path.is_file() and any(
        line.strip() and not line.lstrip().startswith("#")
        for line in fstab_path.read_text(encoding="utf-8").splitlines()
    )
    if not fstab_configured:
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

    locale_gen = files.put(
        name="Install managed locale generation list",
        src=StringIO("".join(f"{locale} UTF-8\n" for locale in settings.system.locales)),
        dest="/etc/locale.gen",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    locale_conf = files.put(
        name="Set the default system locale",
        src=StringIO(f"LANG={settings.system.default_locale}\n"),
        dest="/etc/locale.conf",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    server.shell(
        name="Generate configured locales",
        commands=["/usr/bin/locale-gen"],
        _sudo=SUDO,
        _if=any_changed(locale_gen, locale_conf),
    )
    files.link(
        name="Set the system timezone",
        path="/etc/localtime",
        target=f"/usr/share/zoneinfo/{settings.system.timezone}",
        user="root",
        group="root",
        symbolic=True,
        force=True,
        _sudo=SUDO,
    )
    files.put(
        name="Set the persistent hostname",
        src=StringIO(f"{settings.machine.hostname}\n"),
        dest="/etc/hostname",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    files.line(
        name="Set the local hostname lookup",
        path="/etc/hosts",
        line=f"127.0.1.1        {settings.machine.hostname}",
        replace=r"^127\.0\.1\.1(?:\s+.*)?$",
        ensure_newline=True,
        _sudo=SUDO,
    )

    # The user is created manually before chezmoi can run. Long-term account
    # details converge here after zsh/base packages are installed.
    username = getpass.getuser()
    server.user(
        name="Converge the local login shell and wheel membership",
        user=username,
        shell="/bin/zsh",
        groups=["wheel"],
        append=True,
        _sudo=SUDO,
    )

    autologin_path = "/etc/systemd/system/getty@tty1.service.d/autologin.conf"
    if settings.features.autologin:
        files.template(
            name="Enable tty1 autologin for the local user",
            src="files/systemd/autologin.conf.j2",
            dest=autologin_path,
            user="root",
            group="root",
            mode="644",
            username=username,
            _sudo=SUDO,
        )
    else:
        files.file(
            name="Disable tty1 autologin",
            path=autologin_path,
            present=False,
            _sudo=SUDO,
        )
