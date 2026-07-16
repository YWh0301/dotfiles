#!/bin/sh
set -eu

python - <<'PY'
from pathlib import Path
import json
import os
import tomllib

home = Path.home()
user_config_path = home / ".config/chezmoi/user.toml"
auth_path = home / ".pi/agent/auth.json"

with user_config_path.open("rb") as file:
    user_config = tomllib.load(file)
api_keys = user_config["api_keys"]

if auth_path.exists():
    auth = json.loads(auth_path.read_text(encoding="utf-8"))
else:
    auth = {}

# Synchronize only static API-key credentials. OAuth credentials are
# machine-local, mutable, and are managed by Pi itself.
auth.update({
    "bailian": {"type": "api_key", "key": api_keys["bailian"]},
    "opencode-go": {"type": "api_key", "key": api_keys["opencode_go"]},
    "deepseek": {"type": "api_key", "key": api_keys["deepseek"]},
})

auth_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
temporary = auth_path.with_suffix(".json.tmp")
temporary.write_text(json.dumps(auth, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
os.chmod(temporary, 0o600)
os.replace(temporary, auth_path)
PY
