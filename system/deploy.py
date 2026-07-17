from __future__ import annotations

from pyinfra import config, host, logger
from pyinfra.facts.server import LinuxName

from operations.base_system import configure_base_system
from operations.bootloader import configure_bootloader
from operations.dae import configure_dae
from operations.external_packages import configure_external_packages
from operations.filesystem import configure_filesystem
from operations.firewall import configure_firewall
from operations.packages import configure_packages
from operations.repositories import configure_repositories
from operations.services import configure_services
from operations.sshd import configure_sshd
from package_selection import resolve_package_selection
from runtime import IS_CHROOT
from user_config import config_path, load_user_config


config.REQUIRE_PYINFRA_VERSION = ">=3.9,<4"

settings = load_user_config()
linux_name = host.get_fact(LinuxName)
if "arch" not in linux_name.lower():
    raise RuntimeError(f"personal-system currently supports Arch Linux only, got {linux_name!r}")

logger.info("Loaded machine intent from %s", config_path())
logger.info("Detected operating system: %s", linux_name)
logger.info("Selected proxy backend: %s", settings.proxy.backend)
logger.info("Execution mode: %s", "ArchISO chroot/offline" if IS_CHROOT else "booted system")

selection = resolve_package_selection(settings)
configure_repositories(settings)
package_change = configure_packages(selection)
configure_filesystem()
configure_base_system(settings)
configure_bootloader(package_change)
configure_firewall(settings)
configure_dae(settings)
configure_external_packages(settings, selection)
configure_sshd(settings)
configure_services(settings, selection.hardware)
