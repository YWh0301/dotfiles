from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from operations.filesystem import _has_fstab_entries


class FilesystemTest(unittest.TestCase):
    def test_missing_or_comment_only_fstab_needs_generation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fstab"
            self.assertFalse(_has_fstab_entries(path))
            path.write_text("# generated later\n\n", encoding="utf-8")
            self.assertFalse(_has_fstab_entries(path))

    def test_active_fstab_entry_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fstab"
            path.write_text("# root\nUUID=abcd / ext4 defaults 0 1\n", encoding="utf-8")
            self.assertTrue(_has_fstab_entries(path))


if __name__ == "__main__":
    unittest.main()
