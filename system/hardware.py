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
KNOWN_KERNELS = {
    "linux": "linux-headers",
    "linux-lts": "linux-lts-headers",
    "linux-zen": "linux-zen-headers",
}


def _package_installed(package: str) -> bool:
    return (
        subprocess.run(
            ["/usr/bin/pacman", "-Q", package],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def _nvidia_module_selector() -> str:
    installed_kernels = {
        package for package in KNOWN_KERNELS if _package_installed(package)
    }
    if installed_kernels == {"linux"}:
        return "gpu_nvidia_open"
    if installed_kernels == {"linux-lts"}:
        return "gpu_nvidia_open_lts"

    # Zen, multiple kernels, and unrecognised custom kernels require DKMS. Do
    # not install/remove kernels here: they remain a pacstrap/manual decision.
    if installed_kernels:
        missing_headers = {
            KNOWN_KERNELS[kernel]
            for kernel in installed_kernels
            if not _package_installed(KNOWN_KERNELS[kernel])
        }
        if missing_headers:
            raise RuntimeError(
                "NVIDIA DKMS support requires headers for every installed kernel; missing: "
                + ", ".join(sorted(missing_headers)),
            )
    else:
        running_release = subprocess.check_output(["/usr/bin/uname", "-r"], text=True).strip()
        if not (Path("/usr/lib/modules") / running_release / "build").exists():
            raise RuntimeError(
                "NVIDIA DKMS support for the unrecognised running kernel requires its headers: "
                + running_release,
            )
    return "gpu_nvidia_open_dkms"


def detect_hardware_selectors() -> set[str]:
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
        selectors.add(_nvidia_module_selector())
    return selectors
