from __future__ import annotations

from io import StringIO

from pyinfra.operations import files, server, systemd
from pyinfra.operations.util import any_changed

from runtime import IS_CHROOT, SUDO
from user_config import UserConfig


def _rules_v4(settings: UserConfig) -> str:
    rules = [
        "*filter",
        ":ufw-user-input - [0:0]",
        ":ufw-user-output - [0:0]",
        ":ufw-user-forward - [0:0]",
        ":ufw-user-limit - [0:0]",
        ":ufw-user-limit-accept - [0:0]",
    ]
    if settings.features.sshd:
        rules.append(f"-A ufw-user-input -p tcp --dport {settings.sshd.port} -j ACCEPT")
    if settings.features.localsend:
        for subnet in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"):
            rules.extend(
                (
                    f"-A ufw-user-input -s {subnet} -p tcp --dport 53317 -j ACCEPT",
                    f"-A ufw-user-input -s {subnet} -p udp --dport 53317 -j ACCEPT",
                ),
            )
    if settings.features.tailscale:
        rules.extend(
            (
                "-A ufw-user-input -i tailscale0 -j ACCEPT",
                "-A ufw-user-input -p udp --dport 41641 -j ACCEPT",
            ),
        )
    rules.extend(
        (
            "### RULES ###",
            '-A ufw-user-limit -m limit --limit 3/minute -j LOG --log-prefix "[UFW LIMIT BLOCK] "',
            "-A ufw-user-limit -j REJECT",
            "-A ufw-user-limit-accept -j ACCEPT",
            "COMMIT",
            "",
        ),
    )
    return "\n".join(rules)


def _rules_v6(settings: UserConfig) -> str:
    rules = [
        "*filter",
        ":ufw6-user-input - [0:0]",
        ":ufw6-user-output - [0:0]",
        ":ufw6-user-forward - [0:0]",
        ":ufw6-user-limit - [0:0]",
        ":ufw6-user-limit-accept - [0:0]",
    ]
    if settings.features.sshd:
        rules.append(f"-A ufw6-user-input -p tcp --dport {settings.sshd.port} -j ACCEPT")
    if settings.features.localsend:
        rules.extend(
            (
                "-A ufw6-user-input -s fe80::/10 -p tcp --dport 53317 -j ACCEPT",
                "-A ufw6-user-input -s fe80::/10 -p udp --dport 53317 -j ACCEPT",
            ),
        )
    if settings.features.tailscale:
        rules.extend(
            (
                "-A ufw6-user-input -i tailscale0 -j ACCEPT",
                "-A ufw6-user-input -p udp --dport 41641 -j ACCEPT",
            ),
        )
    rules.extend(
        (
            "### RULES ###",
            '-A ufw6-user-limit -m limit --limit 3/minute -j LOG --log-prefix "[UFW LIMIT BLOCK] "',
            "-A ufw6-user-limit -j REJECT",
            "-A ufw6-user-limit-accept -j ACCEPT",
            "COMMIT",
            "",
        ),
    )
    return "\n".join(rules)


def configure_firewall(settings: UserConfig) -> None:
    ufw_config = files.put(
        name="Enable the managed UFW policy",
        src=StringIO("ENABLED=yes\nLOGLEVEL=low\n"),
        dest="/etc/ufw/ufw.conf",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    ipv4_rules = files.put(
        name="Install managed IPv4 firewall rules",
        src=StringIO(_rules_v4(settings)),
        dest="/etc/ufw/user.rules",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    ipv6_rules = files.put(
        name="Install managed IPv6 firewall rules",
        src=StringIO(_rules_v6(settings)),
        dest="/etc/ufw/user6.rules",
        user="root",
        group="root",
        mode="644",
        _sudo=SUDO,
    )
    server.shell(
        name="Validate managed firewall rules",
        commands=[
            "/usr/bin/iptables-restore --test /etc/ufw/user.rules",
            "/usr/bin/ip6tables-restore --test /etc/ufw/user6.rules",
        ],
        _sudo=SUDO,
        _if=any_changed(ufw_config, ipv4_rules, ipv6_rules),
    )
    systemd.service(
        name="Enable the managed firewall",
        service="ufw.service",
        running=None if IS_CHROOT else True,
        enabled=True,
        _sudo=SUDO,
    )
