# personal-system

`pyinfra` system configuration for local Arch Linux machines. User intent is
read from `~/.config/chezmoi/user.toml`; operating-system and hardware facts are
detected at runtime.

## Bootstrap

Install `uv` from the signed Arch repository:

```sh
sudo pacman -S --needed uv
```

The project uses the PyPI mirror from `user.toml`, a committed `uv.lock`, and a
Git-ignored virtual environment at `system/.venv`.

For a new machine, `manual/installation.md` defines a one-reboot flow. After a
minimal pacstrap and manual user/sudo creation, run chezmoi directly inside
`arch-chroot`. `/run/archiso` (or `PERSONAL_SYSTEM_CHROOT=1`) selects offline
mode: packages, locale, hostname, GRUB, validated configs, and service enablement
are applied, while all service start/reload actions are deferred until the first
boot and its follow-up apply.

## Review and apply

Run an unprivileged plan:

```sh
./system/plan
```

Apply only after reviewing the generated operations:

```sh
./system/apply
```

`system/apply` primes the normal sudo timestamp and refreshes it once per minute
only while that apply process is alive, so long source builds cannot expire it.
The password is handled by sudo and is never passed to pyinfra.

`system/check` emits a machine-readable dry plan and exits with status 10 when
direct drift exists. Pyinfra's conditional-only plan entries are potential
follow-up operations, not drift by themselves, and are deliberately ignored.
`chezmoi apply` invokes this check after user files are applied;
when there is no drift it does not request sudo. In an interactive terminal,
detected drift crosses the sudo boundary, then enters the normal detailed
pyinfra plan/confirmation flow.

## Architecture

`deploy.py` is intentionally only an ordered orchestration file. It loads
`user.toml`, resolves hardware and the package manifest once through
`package_selection.py`, then passes that immutable selection to focused modules
under `operations/`. Controller-side code only inspects local facts and validates
rendered inputs; privileged mutations remain explicit pyinfra operations.

The split is by ownership boundary: repositories and signed Pacman packages,
filesystem bootstrap, base OS identity, bootloader, firewall, DAE, reviewed
external builds, SSH trust, and service state. The external build retry policy is
kept in a standalone auditable shell helper rather than embedded Python strings.

## Current scope

- managed `/etc/pacman.conf` repositories: core, extra, multilib, ArchLinuxCN,
  and Pro Audio;
- concise HTTPS Arch, ArchLinuxCN, and Pro Audio mirror lists from `user.toml`;
- strict parsing of the invisible `<!-- pyinfra: ... -->` selectors attached
  to human-readable package entries in `manual/packages.md`;
- selectors for always-installed, manual, feature-, runtime hardware-, machine-,
  and explicit profile-owned packages;
- package satisfaction checked through `pacman -T`, preserving installed
  provider packages such as `waybar-ywh-git`; Pacman groups are expanded and
  considered satisfied only when every member is installed;
- runtime CPU, multi-GPU, root-filesystem, and installed-kernel detection;
  kernels remain a pacstrap/manual decision, while matching Headers and NVIDIA
  prebuilt/LTS/DKMS modules follow the kernels already installed;
- full `pacman -Syu` only when a selected package is missing, with the
  ArchLinuxCN keyring installed before repository packages;
- DAE configuration deployed to `/etc/dae/config.dae`, validated on change, and
  enabled/started only when `proxy.backend = "dae"`;
- reviewed, Git-metadata-free PKGBUILDs under `pkgbuilds/`, built and installed
  one at a time as the normal user in an explicit dependency order; reusable
  sources and package artifacts live under `~/.cache/personal-system/makepkg/`;
  each build first uses the selected network path, then retries through a
  temporary DAE; failures are recorded under the cache `status/` directory,
  reported after all requested builds, and never abort later pyinfra operations;
  every `makepkg -si` invocation includes `--needed`;
- managed fstab generation, locale, timezone, hostname, login shell, tty1
  autologin, and first-boot GRUB installation/config validation in ArchISO chroot mode;
- NetworkManager, time sync, Bluetooth, CUPS, Tailscale, an optional managed UFW policy selected by `features.firewall`,
  periodic trim/cache maintenance, laptop power management, and global
  PipeWire/WirePlumber user-unit enablement;
- preflight validation of the local SSH certificate followed by CA-only OpenSSH
  trust, principals, port, service state, validation, and reload;
- vendored always-AUR and myPKGBUILDS are a reviewed second transaction after
  the signed Pacman base and proxy configuration have converged.

Package entries are ordinary Markdown bullets such as
`- **git** <!-- pyinfra: always -->`. Supported selectors are `always`, `manual`,
`feature=name`, `hardware=name`, `machine=laptop|desktop`, and `profile=name`.
Profile names are
selected through `[packages].profiles` in `user.toml`. Every bold package bullet
must carry exactly one selector; malformed or conflicting entries fail closed.

`features.snapper` currently controls package installation only. Snapper
subvolume/configuration policy remains a manual step and later module.

## Trust boundary

`chezmoi apply` manages user configuration and explicitly prompts before an SSH
certificate is issued. The unprivileged pyinfra drift check runs afterwards.
Only detected system drift crosses the separate sudo boundary. Neither command
is intended to run unattended from a self-hosted Git service.
