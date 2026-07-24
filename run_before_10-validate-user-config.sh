#!/bin/sh
set -eu

python - <<'PY'
from pathlib import Path, PurePosixPath
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

git = config.get("git", {})
require(isinstance(git.get("general_commit_signing", True), bool),
        "git.general_commit_signing must be boolean when set")
require(git.get("signature_policy", "ask") in {"warn", "ask", "enforce"},
        "git.signature_policy must be warn, ask, or enforce")
origin_patterns = git.get("signed_origin_patterns", [
    "git@github.com:YWh0301/**", "https://github.com/YWh0301/**",
])
require(isinstance(origin_patterns, list) and bool(origin_patterns)
        and all(isinstance(value, str) and bool(value) for value in origin_patterns),
        "git.signed_origin_patterns must be a non-empty string list")

servers = config.get("servers", {})
require(isinstance(servers.get("enabled"), bool), "servers.enabled must be boolean")
servers_root = servers.get("root")
require(isinstance(servers_root, str) and bool(servers_root),
        "servers.root must be a non-empty home-relative path")
if isinstance(servers_root, str) and servers_root:
    root_path = PurePosixPath(servers_root)
    require(not root_path.is_absolute() and ".." not in root_path.parts and root_path != PurePosixPath("."),
            "servers.root must stay below the user's home directory")
repository_url = servers.get("repository_url")
require(isinstance(repository_url, str) and bool(repository_url)
        and not any(character.isspace() for character in repository_url),
        "servers.repository_url must be a non-empty URL without whitespace")
require(isinstance(servers.get("branch"), str)
        and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", servers["branch"])
        and ".." not in servers["branch"] and not servers["branch"].endswith("/"),
        "servers.branch must be a simple Git branch name")
servers_ssh = servers.get("ssh", {})
for key in ("alias", "hostname", "user", "identity_file", "certificate_file"):
    value = servers_ssh.get(key)
    require(isinstance(value, str) and bool(value) and not any(character.isspace() for character in value),
            f"servers.ssh.{key} must be a non-empty value without whitespace")
require(isinstance(servers_ssh.get("port"), int) and 1 <= servers_ssh["port"] <= 65535,
        "servers.ssh.port must be between 1 and 65535")
host_key = servers_ssh.get("host_key")
require(isinstance(host_key, str)
        and re.fullmatch(r"ssh-ed25519 [A-Za-z0-9+/]+={0,3}", host_key) is not None,
        "servers.ssh.host_key must be a complete Ed25519 public key")

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
servers_alias = servers_ssh.get("alias")
require(servers_alias not in set(host_names),
        "servers.ssh.alias must not duplicate a generic ssh host alias")

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
