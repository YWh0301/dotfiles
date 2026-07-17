from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os
import tomllib


@dataclass(frozen=True)
class Features:
    localsend: bool
    sshd: bool
    ssh_user_cert: bool
    wayvnc: bool
    tailscale: bool
    snapper: bool
    autologin: bool


@dataclass(frozen=True)
class Identity:
    name: str


@dataclass(frozen=True)
class Machine:
    kind: str


@dataclass(frozen=True)
class Kernel:
    flavor: str


@dataclass(frozen=True)
class Proxy:
    backend: str
    flclash_http_port: int


@dataclass(frozen=True)
class Sshd:
    port: int


@dataclass(frozen=True)
class Pacman:
    repositories: tuple[str, ...]
    parallel_downloads: int


@dataclass(frozen=True)
class Packages:
    profiles: tuple[str, ...]


@dataclass(frozen=True)
class Mirrors:
    arch: tuple[str, ...]
    archlinuxcn: tuple[str, ...]
    proaudio: tuple[str, ...]
    pypi: str


@dataclass(frozen=True)
class UserConfig:
    identity: Identity
    machine: Machine
    kernel: Kernel
    features: Features
    proxy: Proxy
    sshd: Sshd
    pacman: Pacman
    packages: Packages
    mirrors: Mirrors


def config_path() -> Path:
    override = os.environ.get("PERSONAL_USER_CONFIG")
    return Path(override).expanduser() if override else Path.home() / ".config/chezmoi/user.toml"


def load_user_config(path: Path | None = None) -> UserConfig:
    path = path or config_path()
    with path.open("rb") as file:
        raw = tomllib.load(file)

    if raw.get("schema_version") != 1:
        raise ValueError(f"{path}: schema_version must be 1")

    features = Features(**raw["features"])
    proxy = Proxy(
        backend=raw["proxy"]["backend"],
        flclash_http_port=raw["proxy"]["flclash_http_port"],
    )
    sshd = Sshd(port=raw["sshd"]["port"])
    identity = Identity(name=raw["identity"]["name"])
    machine = Machine(kind=raw["machine"]["kind"])
    kernel = Kernel(flavor=raw["kernel"]["flavor"])
    pacman = Pacman(
        repositories=tuple(raw["pacman"]["repositories"]),
        parallel_downloads=raw["pacman"]["parallel_downloads"],
    )
    packages = Packages(profiles=tuple(raw.get("packages", {}).get("profiles", ())))
    mirrors = Mirrors(
        arch=tuple(raw["mirrors"]["arch"]),
        archlinuxcn=tuple(raw["mirrors"]["archlinuxcn"]),
        proaudio=tuple(raw["mirrors"]["proaudio"]),
        pypi=raw["mirrors"]["pypi"],
    )

    if machine.kind not in {"laptop", "desktop"}:
        raise ValueError(f"{path}: unsupported machine.kind {machine.kind!r}")
    if kernel.flavor not in {"linux", "lts", "zen"}:
        raise ValueError(f"{path}: unsupported kernel.flavor {kernel.flavor!r}")
    if proxy.backend not in {"flclash", "dae"}:
        raise ValueError(f"{path}: unsupported proxy.backend {proxy.backend!r}")
    if not 1 <= proxy.flclash_http_port <= 65535:
        raise ValueError(f"{path}: proxy.flclash_http_port must be between 1 and 65535")
    if not 1 <= sshd.port <= 65535:
        raise ValueError(f"{path}: sshd.port must be between 1 and 65535")
    if not identity.name:
        raise ValueError(f"{path}: identity.name must not be empty")
    allowed_repositories = {"core", "extra", "multilib", "archlinuxcn", "proaudio"}
    if not set(pacman.repositories) <= allowed_repositories:
        raise ValueError(f"{path}: unsupported pacman repository")
    if not {"core", "extra", "archlinuxcn"} <= set(pacman.repositories):
        raise ValueError(f"{path}: core, extra, and archlinuxcn repositories are required")
    if pacman.parallel_downloads < 1:
        raise ValueError(f"{path}: pacman.parallel_downloads must be positive")
    if len(packages.profiles) != len(set(packages.profiles)):
        raise ValueError(f"{path}: packages.profiles must be unique")

    return UserConfig(
        identity=identity,
        machine=machine,
        kernel=kernel,
        features=features,
        proxy=proxy,
        sshd=sshd,
        pacman=pacman,
        packages=packages,
        mirrors=mirrors,
    )
