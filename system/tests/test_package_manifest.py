from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from package_manifest import parse_package_document, select_packages


class PackageManifestTest(unittest.TestCase):
    def parse(self, text: str):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "packages.md"
            path.write_text(text, encoding="utf-8")
            return parse_package_document(path)

    def test_selectors_and_repositories(self) -> None:
        entries = self.parse(
            """
- **base-tool** <!-- pyinfra: always -->
- **laptop-tool** <!-- pyinfra: machine=laptop -->
- **service-tool**(archlinuxcn) <!-- pyinfra: feature=service -->
- **gpu-tool** <!-- pyinfra: hardware=gpu_amd -->
- **editor-tool** <!-- pyinfra: profile=editing -->
- **aur-tool**(AUR) <!-- pyinfra: profile=editing -->
- **custom-tool**(myPKGBUILDS) <!-- pyinfra: always -->
- **notes-only** <!-- pyinfra: manual -->
""",
        )
        pacman, aur, mypkgbuilds, profiles = select_packages(
            entries,
            machine_kind="laptop",
            features={"service": True},
            hardware={"gpu_amd", "gpu_any", "gpu_open"},
            profiles={"editing"},
        )
        self.assertEqual(
            pacman,
            {"base-tool", "laptop-tool", "service-tool", "gpu-tool", "editor-tool"},
        )
        self.assertEqual(aur, {"aur-tool"})
        self.assertEqual(mypkgbuilds, {"custom-tool"})
        self.assertEqual(profiles, {"editing"})

    def test_missing_tag_fails_closed(self) -> None:
        with self.assertRaisesRegex(ValueError, "exactly one pyinfra tag"):
            self.parse("- **untagged-package**\n")

    def test_unknown_profile_fails(self) -> None:
        entries = self.parse("- **editor-tool** <!-- pyinfra: profile=editing -->\n")
        with self.assertRaisesRegex(ValueError, "unknown package profiles"):
            select_packages(
                entries,
                machine_kind="desktop",
                features={},
                hardware=set(),
                profiles={"missing"},
            )

    def test_conflicting_duplicate_fails(self) -> None:
        with self.assertRaisesRegex(ValueError, "conflicting duplicate"):
            self.parse(
                """
- **same-package** <!-- pyinfra: always -->
- **same-package** <!-- pyinfra: manual -->
""",
            )


if __name__ == "__main__":
    unittest.main()
