from __future__ import annotations

from dataclasses import asdict, dataclass

from hardware import detect_hardware_selectors
from package_manifest import PackageEntry, parse_package_document, select_packages
from user_config import UserConfig


@dataclass(frozen=True)
class PackageSelection:
    entries: tuple[PackageEntry, ...]
    hardware: frozenset[str]
    pacman: frozenset[str]
    aur: frozenset[str]
    mypkgbuilds: frozenset[str]
    profiles: frozenset[str]

    @property
    def reviewed_aur(self) -> frozenset[str]:
        return frozenset(
            entry.name
            for entry in self.entries
            if entry.repository == "aur" and entry.selector == "always"
        )

    @property
    def external_builds(self) -> frozenset[str]:
        return self.reviewed_aur | self.mypkgbuilds

    @property
    def deferred_aur(self) -> frozenset[str]:
        return self.aur - self.reviewed_aur


def resolve_package_selection(settings: UserConfig) -> PackageSelection:
    entries = tuple(parse_package_document())
    hardware = frozenset(detect_hardware_selectors())
    pacman, aur, mypkgbuilds, profiles = select_packages(
        list(entries),
        machine_kind=settings.machine.kind,
        features=asdict(settings.features),
        hardware=set(hardware),
        profiles=set(settings.packages.profiles),
    )
    return PackageSelection(
        entries=entries,
        hardware=hardware,
        pacman=frozenset(pacman),
        aur=frozenset(aur),
        mypkgbuilds=frozenset(mypkgbuilds),
        profiles=frozenset(profiles),
    )
