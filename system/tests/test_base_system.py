from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()
