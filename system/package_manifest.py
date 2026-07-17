from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


PACKAGE_DOCUMENT = Path(__file__).resolve().parent.parent / "manual/packages.md"
PACKAGE_LINE = re.compile(r"^\s*-\s+\*\*([^*]+)\*\*(.*)$")
PYINFRA_TAG = re.compile(r"<!--\s*pyinfra:\s*([^>]+?)\s*-->")
VALID_PACKAGE = re.compile(r"^[A-Za-z0-9@._+:-]+$")
VALID_VALUE = re.compile(r"^[a-z][a-z0-9_-]*$")
SUPPORTED_HARDWARE = {
    "cpu_amd",
    "cpu_intel",
    "fs_btrfs",
    "gpu_amd",
    "gpu_any",
    "gpu_intel",
    "gpu_nvidia",
    "gpu_nvidia_open",
    "gpu_nvidia_open_dkms",
    "gpu_nvidia_open_lts",
    "gpu_open",
    "kernel_linux",
    "kernel_lts",
    "kernel_zen",
}
SUPPORTED_MACHINE_KINDS = {"desktop", "laptop"}


@dataclass(frozen=True)
class PackageEntry:
    name: str
    selector: str
    value: str | None
    repository: str
    line: int


def _parse_selector(raw: str, *, line: int) -> tuple[str, str | None]:
    raw = raw.strip()
    if raw in {"always", "manual"}:
        return raw, None
    if "=" not in raw:
        raise ValueError(f"{PACKAGE_DOCUMENT}:{line}: invalid pyinfra selector {raw!r}")
    selector, value = (part.strip() for part in raw.split("=", 1))
    if selector not in {"feature", "hardware", "machine", "profile"}:
        raise ValueError(f"{PACKAGE_DOCUMENT}:{line}: unknown pyinfra selector {selector!r}")
    if not VALID_VALUE.fullmatch(value):
        raise ValueError(f"{PACKAGE_DOCUMENT}:{line}: invalid selector value {value!r}")
    if selector == "hardware" and value not in SUPPORTED_HARDWARE:
        raise ValueError(f"{PACKAGE_DOCUMENT}:{line}: unsupported hardware selector {value!r}")
    if selector == "machine" and value not in SUPPORTED_MACHINE_KINDS:
        raise ValueError(f"{PACKAGE_DOCUMENT}:{line}: unsupported machine selector {value!r}")
    return selector, value


def parse_package_document(path: Path = PACKAGE_DOCUMENT) -> list[PackageEntry]:
    entries: dict[str, PackageEntry] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        package_match = PACKAGE_LINE.match(line)
        if not package_match:
            continue

        name, suffix = package_match.groups()
        name = name.strip()
        if not VALID_PACKAGE.fullmatch(name):
            raise ValueError(f"{path}:{line_number}: invalid package name {name!r}")
        tags = PYINFRA_TAG.findall(suffix)
        if len(tags) != 1:
            raise ValueError(
                f"{path}:{line_number}: package {name!r} must have exactly one pyinfra tag",
            )
        selector, value = _parse_selector(tags[0], line=line_number)

        annotation = suffix.lower()
        if "(aur)" in annotation:
            repository = "aur"
        elif "(archlinuxcn)" in annotation:
            repository = "archlinuxcn"
        elif "(pro-audio)" in annotation or "(proaudio)" in annotation:
            repository = "proaudio"
        elif "(mypkgbuilds)" in annotation:
            repository = "mypkgbuilds"
        else:
            repository = "official"

        entry = PackageEntry(name, selector, value, repository, line_number)
        previous = entries.get(name)
        if previous and (previous.selector, previous.value, previous.repository) != (
            entry.selector,
            entry.value,
            entry.repository,
        ):
            raise ValueError(
                f"{path}:{line_number}: conflicting duplicate package {name!r}; "
                f"first declared on line {previous.line}",
            )
        entries[name] = entry
    if not entries:
        raise ValueError(f"{path}: no package entries found")
    return list(entries.values())


def select_packages(
    entries: list[PackageEntry],
    *,
    machine_kind: str,
    features: dict[str, bool],
    hardware: set[str],
    profiles: set[str],
) -> tuple[set[str], set[str], set[str], set[str]]:
    known_features = set(features)
    referenced_features = {entry.value for entry in entries if entry.selector == "feature"}
    unknown_features = referenced_features - known_features
    if unknown_features:
        raise ValueError(f"unknown package features: {', '.join(sorted(unknown_features))}")

    known_profiles = {entry.value for entry in entries if entry.selector == "profile"}
    unknown_profiles = profiles - known_profiles
    if unknown_profiles:
        raise ValueError(f"unknown package profiles: {', '.join(sorted(unknown_profiles))}")

    pacman: set[str] = set()
    aur: set[str] = set()
    mypkgbuilds: set[str] = set()
    selected_profiles: set[str] = set()
    for entry in entries:
        selected = (
            entry.selector == "always"
            or (entry.selector == "machine" and entry.value == machine_kind)
            or (entry.selector == "feature" and features.get(entry.value or "", False))
            or (entry.selector == "hardware" and entry.value in hardware)
            or (entry.selector == "profile" and entry.value in profiles)
        )
        if not selected:
            continue
        if entry.selector == "profile" and entry.value:
            selected_profiles.add(entry.value)
        if entry.repository == "aur":
            aur.add(entry.name)
        elif entry.repository == "mypkgbuilds":
            mypkgbuilds.add(entry.name)
        else:
            pacman.add(entry.name)
    return pacman, aur, mypkgbuilds, selected_profiles
