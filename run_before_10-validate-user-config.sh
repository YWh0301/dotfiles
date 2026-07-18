#!/bin/sh
set -eu

python - <<'PY'
from pathlib import Path
import re
import tomllib

path = Path.home() / ".config/chezmoi/user.toml"
with path.open("rb") as file:
    config = tomllib.load(file)

errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

require(config.get("schema_version") == 1, "schema_version must be 1")
require(config.get("machine", {}).get("kind") in {"laptop", "desktop"},
        "machine.kind must be laptop or desktop")
hostname = config.get("machine", {}).get("hostname")
require(isinstance(hostname, str) and bool(hostname) and not any(c.isspace() for c in hostname),
        "machine.hostname must be a non-empty DNS-style name")
system = config.get("system", {})
locales = system.get("locales", [])
require(isinstance(locales, list) and bool(locales) and all(isinstance(x, str) for x in locales),
        "system.locales must be a non-empty string list")
require(system.get("default_locale") in locales,
        "system.default_locale must be included in system.locales")
require(isinstance(system.get("timezone"), str) and bool(system.get("timezone")),
        "system.timezone must be a non-empty string")
require(config.get("proxy", {}).get("backend") in {"flclash", "dae"},
        "proxy.backend must be flclash or dae")

for section, key in (("kitty", "font_size"), ("sshd", "port"), ("wayvnc", "port"), ("proxy", "flclash_http_port")):
    value = config.get(section, {}).get(key)
    require(isinstance(value, int) and value > 0, f"{section}.{key} must be a positive integer")

features = config.get("features", {})
for key in ("localsend", "sshd", "ssh_user_cert", "wayvnc", "tailscale", "firewall", "snapper", "autologin"):
    require(isinstance(features.get(key), bool), f"features.{key} must be boolean")
require(isinstance(features.get("git_commit_signing", True), bool),
        "features.git_commit_signing must be boolean when set")

package_profiles = config.get("packages", {}).get("profiles", [])
require(isinstance(package_profiles, list), "packages.profiles must be a list")
require(all(isinstance(value, str) and re.fullmatch(r"[a-z][a-z0-9_-]*", value)
            for value in package_profiles), "packages.profiles contains an invalid name")
require(len(package_profiles) == len(set(package_profiles)), "packages.profiles must be unique")

providers = config.get("proxy", {}).get("providers", [])
provider_names = [provider.get("name") for provider in providers]
require(len(provider_names) == len(set(provider_names)), "proxy provider names must be unique")
default_provider = config.get("proxy", {}).get("default_provider")
require(default_provider in set(provider_names), "proxy.default_provider must name an existing provider")

pacman = config.get("pacman", {})
repositories = pacman.get("repositories", [])
allowed_repositories = {"core", "extra", "multilib", "archlinuxcn", "proaudio"}
require(isinstance(repositories, list), "pacman.repositories must be a list")
require(set(repositories) <= allowed_repositories, "pacman.repositories contains an unsupported repository")
require({"core", "extra", "archlinuxcn"} <= set(repositories),
        "pacman.repositories must include core, extra, and archlinuxcn")
require(isinstance(pacman.get("parallel_downloads"), int) and pacman["parallel_downloads"] > 0,
        "pacman.parallel_downloads must be a positive integer")
for key in ("arch", "archlinuxcn", "proaudio"):
    value = config.get("mirrors", {}).get(key)
    require(isinstance(value, list) and bool(value), f"mirrors.{key} must be a non-empty list")

hosts = config.get("ssh", {}).get("hosts", [])
host_names = [host.get("name") for host in hosts]
require(len(host_names) == len(set(host_names)), "ssh host aliases must be unique")

for dotted in (
    "identity.name", "git.email", "wayvnc.username", "wayvnc.password",
    "api_keys.deepseek", "api_keys.opencode_go", "api_keys.bailian",
):
    section, key = dotted.split(".", 1)
    value = config.get(section, {}).get(key)
    require(isinstance(value, str) and bool(value), f"{dotted} must be a non-empty string")

if errors:
    raise SystemExit("Invalid user.toml:\n- " + "\n- ".join(errors))
PY
