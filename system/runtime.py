from __future__ import annotations

import os


# Plans gather only read-only facts, all of which are world-readable on the
# supported Arch setup. Real applies use sudo per operation.
IS_PLAN = os.environ.get("PERSONAL_SYSTEM_PLAN") == "1"
SUDO = not IS_PLAN
