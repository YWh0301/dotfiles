from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
import unittest

from operations.firewall import _rules_v4, _rules_v6


UFW_PREFLIGHT = (
    Path(__file__).resolve().parents[1] / "files/systemd/ufw-validate.conf.j2"
)


class FirewallTest(unittest.TestCase):
    def settings(self, *, sshd=True, localsend=True, tailscale=True):
        return SimpleNamespace(
            features=SimpleNamespace(
                sshd=sshd,
                localsend=localsend,
                tailscale=tailscale,
            ),
            sshd=SimpleNamespace(port=2222),
        )

    def test_enabled_features_add_scoped_rules(self) -> None:
        ipv4 = _rules_v4(self.settings())
        ipv6 = _rules_v6(self.settings())
        self.assertIn("--dport 2222", ipv4)
        self.assertIn("192.168.0.0/16", ipv4)
        self.assertIn("--dport 53317", ipv6)
        self.assertIn("-i tailscale0", ipv4)
        self.assertTrue(ipv4.endswith("COMMIT\n"))
        self.assertTrue(ipv6.endswith("COMMIT\n"))

    def test_disabled_features_leave_ports_closed(self) -> None:
        ipv4 = _rules_v4(self.settings(sshd=False, localsend=False, tailscale=False))
        self.assertNotIn("--dport 2222", ipv4)
        self.assertNotIn("--dport 53317", ipv4)
        self.assertNotIn("tailscale0", ipv4)

    def test_service_preflight_uses_an_isolated_network_namespace(self) -> None:
        text = UFW_PREFLIGHT.read_text(encoding="utf-8")
        self.assertIn("ConditionPathExists=/usr/lib/modules/%v", text)
        self.assertIn("ExecStartPre=/usr/bin/unshare --net --", text)
        self.assertIn("/usr/lib/ufw/ufw-init start", text)


if __name__ == "__main__":
    unittest.main()
