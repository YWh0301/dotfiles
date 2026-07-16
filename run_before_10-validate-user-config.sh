#!/bin/sh
set -eu

python - <<'PY'
from pathlib import Path
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
require(config.get("proxy", {}).get("backend") in {"flclash", "dae", "daed"},
        "proxy.backend must be flclash, dae, or daed")

for section, key in (("kitty", "font_size"), ("sshd", "port"), ("wayvnc", "port")):
    value = config.get(section, {}).get(key)
    require(isinstance(value, int) and value > 0, f"{section}.{key} must be a positive integer")

features = config.get("features", {})
for key in ("localsend", "sshd", "wayvnc", "tailscale", "snapper", "autologin"):
    require(isinstance(features.get(key), bool), f"features.{key} must be boolean")

providers = config.get("proxy", {}).get("providers", [])
provider_names = [provider.get("name") for provider in providers]
require(len(provider_names) == len(set(provider_names)), "proxy provider names must be unique")
default_provider = config.get("proxy", {}).get("default_provider")
enabled_names = {provider.get("name") for provider in providers if provider.get("enabled") is True}
require(default_provider in enabled_names, "proxy.default_provider must name an enabled provider")

hosts = config.get("ssh", {}).get("hosts", [])
host_names = [host.get("name") for host in hosts]
require(len(host_names) == len(set(host_names)), "ssh host aliases must be unique")

for dotted in (
    "identity.name", "git.email", "ssh.key_comment", "wayvnc.username", "wayvnc.password",
    "api_keys.deepseek", "api_keys.opencode_go", "api_keys.bailian",
):
    section, key = dotted.split(".", 1)
    value = config.get(section, {}).get(key)
    require(isinstance(value, str) and bool(value), f"{dotted} must be a non-empty string")

if errors:
    raise SystemExit("Invalid user.toml:\n- " + "\n- ".join(errors))
PY
