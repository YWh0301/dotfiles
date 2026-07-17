from __future__ import annotations

from pathlib import Path
import subprocess
import unittest

from operations.external_packages import (
    BUILD_DEPENDENCIES,
    _build_dependency_cleanup_command,
    _srcinfo_build_dependencies,
)


SYSTEM_ROOT = Path(__file__).resolve().parents[1]
BUILD_HELPER = SYSTEM_ROOT / "files/scripts/build-external-with-dae"
MAKEPKG_CONFIG = SYSTEM_ROOT / "files/makepkg/noninteractive.conf"
EXTERNAL_OPERATION = SYSTEM_ROOT / "operations/external_packages.py"


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
        self.assertIn('sudo -n -v', text)
        self.assertIn('--config "${MAKEPKG_CONFIG}"', text)
        self.assertIn("trap cleanup_dae", text)
        self.assertIn("record_failure", text)
        self.assertIn("continuing deployment", text)

    def test_makepkg_never_prompts_for_sudo(self) -> None:
        text = MAKEPKG_CONFIG.read_text(encoding="utf-8")
        self.assertIn("PACMAN_AUTH=(sudo -n)", text)

    def test_reviewed_external_dependencies_are_explicit(self) -> None:
        self.assertEqual(
            BUILD_DEPENDENCIES["python-pdfplumber"],
            ("python-pypdfium2",),
        )
        self.assertEqual(
            BUILD_DEPENDENCIES["pi-ext-pdf"],
            ("python-pdfplumber",),
        )

    def test_unexpected_helper_failure_is_reported_but_nonfatal(self) -> None:
        text = EXTERNAL_OPERATION.read_text(encoding="utf-8")
        self.assertIn("unexpected build helper exit", text)
        self.assertIn('if ! test -s', text)
        self.assertIn("_ignore_errors=True", text)
        self.assertIn("Report external package build results", text)
        self.assertIn("deployment continued", text)

    def test_vivify_build_dependencies_come_from_srcinfo(self) -> None:
        dependencies = _srcinfo_build_dependencies(
            SYSTEM_ROOT.parent / "pkgbuilds/vivify",
        )
        self.assertEqual(dependencies, {"nvm", "yarn", "zip"})

    def test_build_dependency_cleanup_is_success_gated_and_orphan_only(self) -> None:
        command = _build_dependency_cleanup_command(
            ["nvm", "yarn", "zip"],
            [Path("/tmp/vivify.failure")],
        )
        subprocess.run(["/usr/bin/sh", "-n", "-c", command], check=True)
        self.assertIn("skipping external build dependency cleanup because a build failed", command)
        self.assertIn("pacman -Qdtq", command)
        self.assertIn("pacman -Rns --noconfirm", command)


if __name__ == "__main__":
    unittest.main()
