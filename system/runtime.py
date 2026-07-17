from __future__ import annotations

import os
from pathlib import Path


# ArchISO's /run is bind-mounted by arch-chroot. The environment override also
# supports other rescue media and tests.
IS_CHROOT = (
    os.environ.get("PERSONAL_SYSTEM_CHROOT") == "1"
    or Path("/run/archiso").exists()
)


# Plans gather only read-only facts, all of which are world-readable on the
# supported Arch setup. Real applies use sudo per operation.
IS_PLAN = os.environ.get("PERSONAL_SYSTEM_PLAN") == "1"
SUDO = not IS_PLAN
