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

## Review and apply

Run an unprivileged plan:

```sh
./system/plan
```

Apply only after reviewing the generated operations:

```sh
./system/apply
```

`system/apply` primes the normal sudo timestamp once. The password is handled by
sudo and is never passed to pyinfra.

`system/check` emits a machine-readable dry plan and exits with status 10 when
direct drift exists. Pyinfra's conditional-only plan entries are potential
follow-up operations, not drift by themselves, and are deliberately ignored.
`chezmoi apply` invokes this check after user files are applied;
when there is no drift it does not request sudo. In an interactive terminal,
detected drift crosses the sudo boundary, then enters the normal detailed
pyinfra plan/confirmation flow.

## Current scope

- managed `/etc/pacman.conf` repositories: core, extra, multilib, ArchLinuxCN,
  and Pro Audio;
- concise HTTPS Arch, ArchLinuxCN, and Pro Audio mirror lists from `user.toml`;
- strict parsing of the invisible `<!-- pyinfra: ... -->` selectors attached
  to human-readable package entries in `manual/packages.md`;
- selectors for always-installed, manual, feature-, runtime hardware-, machine-,
  and explicit profile-owned packages; selected AUR/myPKGBUILDS packages are
  reported but not installed;
- package satisfaction checked through `pacman -T`, preserving installed
  provider packages such as `waybar-ywh-git`; Pacman groups are expanded and
  considered satisfied only when every member is installed;
- runtime CPU, multi-GPU, root-filesystem, and installed-kernel detection;
  kernels remain a pacstrap/manual decision, while NVIDIA prebuilt/LTS/DKMS
  modules follow the kernels already installed and fail if DKMS headers are missing;
- full `pacman -Syu` only when a selected package is missing, with the
  ArchLinuxCN keyring installed before repository packages;
- DAE configuration deployed to `/etc/dae/config.dae`, validated on change, and
  enabled/started only when `proxy.backend = "dae"`;
- reviewed, Git-metadata-free PKGBUILDs under `pkgbuilds/`, built as the normal
  user in an explicit dependency order only after the selected proxy/network is
  reachable; every `makepkg -si` invocation includes `--needed`;
- Tailscale systemd service state;
- preflight validation of the local SSH certificate followed by CA-only OpenSSH
  trust, principals, port, service state, validation, and reload;
- no AUR dependency during base bootstrap.

Package entries are ordinary Markdown bullets such as
`- **git** <!-- pyinfra: always -->`. Supported selectors are `always`, `manual`,
`feature=name`, `hardware=name`, `machine=laptop|desktop`, and `profile=name`.
Profile names are
selected through `[packages].profiles` in `user.toml`. Every bold package bullet
must carry exactly one selector; malformed or conflicting entries fail closed.

LocalSend is intentionally reported but not installed until an AUR or private
repository is available. Snapper and autologin configuration will be added in
later modules.

## Trust boundary

`chezmoi apply` manages user configuration and explicitly prompts before an SSH
certificate is issued. The unprivileged pyinfra drift check runs afterwards.
Only detected system drift crosses the separate sudo boundary. Neither command
is intended to run unattended from a self-hosted Git service.
