from __future__ import annotations

from pathlib import Path
import py_compile
import subprocess
import tempfile
import unittest


SOURCE_ROOT = Path(__file__).resolve().parents[2]
CHEZMOI = "/usr/bin/chezmoi"


def render(relative: str) -> str:
    template = (SOURCE_ROOT / relative).read_text(encoding="utf-8")
    result = subprocess.run(
        [CHEZMOI, "execute-template"],
        input=template,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return result.stdout


class ServersBootstrapTest(unittest.TestCase):
    def test_shared_config_derives_all_paths_from_one_root(self) -> None:
        text = render(".chezmoitemplates/servers-config.toml")
        self.assertIn('root = "/home/', text)
        self.assertIn('/.local/share/servers"', text)
        self.assertIn('/.local/share/servers/scripts"', text)
        self.assertIn('/.local/share/servers/scripts/serverctl"', text)

    def test_sync_hook_is_valid_python_and_never_updates_the_worktree(self) -> None:
        text = render("run_after_95-sync-servers.py.tmpl")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sync_servers.py"
            path.write_text(text, encoding="utf-8")
            py_compile.compile(str(path), doraise=True)
        self.assertIn('"fetch", "--prune"', text)
        self.assertIn("NETWORK_TIMEOUT_SECONDS = 90", text)
        self.assertIn("timeout=NETWORK_TIMEOUT_SECONDS", text)
        self.assertIn('"personal.signaturePolicy", "enforce"', text)
        self.assertNotIn('"pull"', text)
        self.assertNotIn('"merge"', text)
        self.assertNotIn('"rebase"', text)
        self.assertNotIn('"reset"', text)

    def test_git_config_selects_personal_ca_for_servers_origin(self) -> None:
        text = render("dot_gitconfig.tmpl")
        self.assertIn(
            'hasconfig:remote.*.url:personal-servers:/srv/git/servers.git',
            text,
        )
        self.assertIn("~/.config/git/personal-origin-signing.conf", text)

    def test_ssh_bootstrap_is_pinned_and_fail_closed(self) -> None:
        config = render("private_dot_ssh/private_config.tmpl")
        known_hosts = render(
            "private_dot_ssh/private_known_hosts.personal-servers.tmpl"
        )
        self.assertIn("Host personal-servers", config)
        self.assertIn("StrictHostKeyChecking yes", config)
        self.assertIn("HostKeyAlias personal-servers", config)
        self.assertIn("personal-servers ssh-ed25519 ", known_hosts)


if __name__ == "__main__":
    unittest.main()
