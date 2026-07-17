from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from operations import base_system
from operations.base_system import _enabled_locales


class BaseSystemTest(unittest.TestCase):
    def test_locale_detection_ignores_comments_and_spacing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "locale.gen"
            path.write_text(
                "#de_DE.UTF-8 UTF-8\n"
                "en_US.UTF-8 UTF-8  \n"
                "zh_CN.UTF-8 UTF-8\n",
                encoding="utf-8",
            )
            self.assertEqual(
                _enabled_locales(path),
                {"en_US.UTF-8", "zh_CN.UTF-8"},
            )

    def test_hosts_line_uses_regex_as_match_and_hostname_as_replacement(self) -> None:
        text = Path(base_system.__file__).read_text(encoding="utf-8")
        self.assertIn('line=r"^127\\.0\\.1\\.1[[:space:]]+.*$"', text)
        self.assertIn('replace=f"127.0.1.1        {settings.machine.hostname}"', text)


if __name__ == "__main__":
    unittest.main()
