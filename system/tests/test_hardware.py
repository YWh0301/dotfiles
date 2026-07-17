from __future__ import annotations

import unittest
from unittest.mock import patch

import hardware


class NvidiaKernelCompatibilityTest(unittest.TestCase):
    @staticmethod
    def installed(*names: str):
        selected = set(names)
        return patch("hardware._package_installed", side_effect=lambda name: name in selected)

    def test_standard_kernel_uses_prebuilt_module(self) -> None:
        with self.installed("linux"):
            self.assertEqual(hardware._nvidia_module_selector(), "gpu_nvidia_open")

    def test_lts_kernel_uses_lts_module(self) -> None:
        with self.installed("linux-lts"):
            self.assertEqual(hardware._nvidia_module_selector(), "gpu_nvidia_open_lts")

    def test_zen_kernel_uses_dkms_when_headers_exist(self) -> None:
        with self.installed("linux-zen", "linux-zen-headers"):
            self.assertEqual(hardware._nvidia_module_selector(), "gpu_nvidia_open_dkms")

    def test_multiple_kernels_use_dkms(self) -> None:
        with self.installed("linux", "linux-headers", "linux-zen", "linux-zen-headers"):
            self.assertEqual(hardware._nvidia_module_selector(), "gpu_nvidia_open_dkms")

    def test_dkms_fails_closed_without_headers(self) -> None:
        with self.installed("linux-zen"):
            with self.assertRaisesRegex(RuntimeError, "linux-zen-headers"):
                hardware._nvidia_module_selector()


if __name__ == "__main__":
    unittest.main()
