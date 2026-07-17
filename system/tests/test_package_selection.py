from __future__ import annotations

import unittest

from package_manifest import PackageEntry
from package_selection import PackageSelection


class PackageSelectionTest(unittest.TestCase):
    def test_external_boundary_only_auto_builds_always_aur(self) -> None:
        selection = PackageSelection(
            entries=(
                PackageEntry("reviewed", "always", None, "aur", 1),
                PackageEntry("profile-only", "profile", "audio", "aur", 2),
                PackageEntry("private-build", "always", None, "mypkgbuilds", 3),
            ),
            hardware=frozenset(),
            pacman=frozenset(),
            aur=frozenset({"reviewed", "profile-only"}),
            mypkgbuilds=frozenset({"private-build"}),
            profiles=frozenset({"audio"}),
        )
        self.assertEqual(
            selection.external_builds,
            {"reviewed", "private-build"},
        )
        self.assertEqual(selection.deferred_aur, {"profile-only"})


if __name__ == "__main__":
    unittest.main()
