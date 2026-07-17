from __future__ import annotations

from pathlib import Path
import subprocess
import unittest


SYSTEM_ROOT = Path(__file__).resolve().parents[1]


class RunnerScriptTest(unittest.TestCase):
    def test_apply_script_is_valid_shell_and_keeps_sudo_alive(self) -> None:
        apply = SYSTEM_ROOT / "apply"
        subprocess.run(["/usr/bin/sh", "-n", str(apply)], check=True)
        text = apply.read_text(encoding="utf-8")
        self.assertIn("sudo -n -v", text)
        self.assertIn("trap cleanup", text)


if __name__ == "__main__":
    unittest.main()
