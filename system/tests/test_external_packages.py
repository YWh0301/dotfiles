from __future__ import annotations

from pathlib import Path
import subprocess
import unittest


BUILD_HELPER = (
    Path(__file__).resolve().parents[1] / "files/scripts/build-external-with-dae"
)


class ExternalPackageHelperTest(unittest.TestCase):
    def test_build_helper_is_executable_valid_bash(self) -> None:
        self.assertTrue(BUILD_HELPER.is_file())
        self.assertNotEqual(BUILD_HELPER.stat().st_mode & 0o111, 0)
        subprocess.run(
            ["/usr/bin/bash", "-n", str(BUILD_HELPER)],
            check=True,
        )

    def test_build_helper_keeps_needed_and_cleanup_guards(self) -> None:
        text = BUILD_HELPER.read_text(encoding="utf-8")
        self.assertIn("--needed", text)
        self.assertIn("install_cached_package", text)
        self.assertIn("trap cleanup_dae", text)
        self.assertIn("deferring ${package}", text)


if __name__ == "__main__":
    unittest.main()
