from __future__ import annotations

import shlex
import unittest

from operations.packages import (
    KNOWN_PACKAGE_TRANSITIONS,
    _install_command,
    _managed_repository_packages,
)
from package_manifest import PackageEntry
from package_selection import PackageSelection


class PackageOperationTest(unittest.TestCase):
    def test_reviewed_transitions_are_explicit(self) -> None:
        self.assertEqual(KNOWN_PACKAGE_TRANSITIONS["dae-git"], "dae")
        self.assertEqual(KNOWN_PACKAGE_TRANSITIONS["exfatprogs"], "exfat-utils")
        self.assertEqual(KNOWN_PACKAGE_TRANSITIONS["pandoc-bin"], "pandoc-cli")
        self.assertEqual(
            KNOWN_PACKAGE_TRANSITIONS["zathura-pdf-mupdf"],
            "zathura-pdf-poppler",
        )

    def test_managed_repository_packages_can_be_planned_before_repo_convergence(self) -> None:
        entries = (
            PackageEntry("git", "always", None, "official", 1),
            PackageEntry("vcvrack", "profile", "proaudio", "proaudio", 2),
            PackageEntry("yay", "always", None, "archlinuxcn", 3),
        )
        selection = PackageSelection(
            entries=entries,
            hardware=frozenset(),
            pacman=frozenset({"git", "vcvrack", "yay"}),
            aur=frozenset(),
            mypkgbuilds=frozenset(),
            profiles=frozenset({"proaudio"}),
        )
        self.assertEqual(
            _managed_repository_packages(selection),
            {"vcvrack", "yay"},
        )

    def test_conflict_acceptance_is_scoped_command_flag(self) -> None:
        command = shlex.split(
            _install_command(
                {"pandoc-bin"},
                refresh_and_upgrade=False,
                accept_known_conflict=True,
            ),
        )
        self.assertEqual(command[-1], "pandoc-bin")
        self.assertIn("--ask", command)
        self.assertIn("4", command)


if __name__ == "__main__":
    unittest.main()
