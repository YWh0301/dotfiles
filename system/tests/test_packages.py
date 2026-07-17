from __future__ import annotations

import shlex
import unittest

from operations.packages import KNOWN_PACKAGE_TRANSITIONS, _install_command


class PackageOperationTest(unittest.TestCase):
    def test_reviewed_transitions_are_explicit(self) -> None:
        self.assertEqual(KNOWN_PACKAGE_TRANSITIONS["exfatprogs"], "exfat-utils")
        self.assertEqual(KNOWN_PACKAGE_TRANSITIONS["pandoc-bin"], "pandoc-cli")
        self.assertEqual(
            KNOWN_PACKAGE_TRANSITIONS["zathura-pdf-poppler"],
            "zathura-pdf-mupdf",
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
