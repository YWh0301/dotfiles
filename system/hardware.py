from __future__ import annotations

from pathlib import Path
import subprocess


CPU_VENDOR_SELECTORS = {
    "GenuineIntel": "cpu_intel",
    "AuthenticAMD": "cpu_amd",
}
GPU_VENDOR_SELECTORS = {
    "0x8086": "gpu_intel",
    "0x1002": "gpu_amd",
    "0x10de": "gpu_nvidia",
}


def detect_hardware_selectors(kernel_flavor: str) -> set[str]:
    selectors: set[str] = set()

    root_filesystem = subprocess.run(
        ["/usr/bin/findmnt", "--noheadings", "--output", "FSTYPE", "/"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    if root_filesystem == "btrfs":
        selectors.add("fs_btrfs")

    cpuinfo = Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace")
    for line in cpuinfo.splitlines():
        if line.startswith("vendor_id"):
            vendor = line.split(":", 1)[1].strip()
            selector = CPU_VENDOR_SELECTORS.get(vendor)
            if selector:
                selectors.add(selector)
            break

    for vendor_file in Path("/sys/class/drm").glob("card*/device/vendor"):
        try:
            vendor = vendor_file.read_text(encoding="ascii").strip().lower()
        except OSError:
            continue
        selector = GPU_VENDOR_SELECTORS.get(vendor)
        if selector:
            selectors.add(selector)

    gpu_selectors = selectors & {"gpu_intel", "gpu_amd", "gpu_nvidia"}
    if gpu_selectors:
        selectors.add("gpu_any")
    if gpu_selectors & {"gpu_intel", "gpu_amd"}:
        selectors.add("gpu_open")

    if "gpu_nvidia" in selectors:
        # The configured kernel, not the currently booted kernel, determines
        # which NVIDIA module package must converge. Alternate kernels use DKMS.
        selectors.add(
            {
                "linux": "gpu_nvidia_open",
                "lts": "gpu_nvidia_open_lts",
                "zen": "gpu_nvidia_open_dkms",
            }[kernel_flavor],
        )
    return selectors
