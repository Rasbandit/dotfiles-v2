# CLI Tools Runbook

Single source of truth for every CLI tool managed by this dotfiles repo.

**When adding a new tool, update ALL applicable columns below, then:**
1. Add the package to the relevant Ansible role task(s)
2. Add a guard-wrapped alias/function in `dot_aliases` or `dot_bash_functions`
3. Add it to `bootstrap.sh` temporary section if it's a terminal essential
4. Update this file

---

## Terminal Essentials (all machine types)

| Tool | Purpose | Fedora pkg | Debian pkg | Alias/Function | Notes |
|------|---------|-----------|------------|----------------|-------|
| `starship` | Shell prompt | installed via curl | installed via curl | init in `.bashrc` | `base` role |
| `fzf` | Fuzzy finder | `fzf` | `fzf` | integrated with shell | `fedora`/`debian` role |
| `zoxide` | Smart `cd` | `zoxide` | `zoxide` | `cd`, `..`, `...`, `~` | guards in `.aliases` |
| `ripgrep` / `rg` | Fast grep | `ripgrep` | `ripgrep` | `grep`, `egrep`, `fgrep` | guards in `.aliases` |
| `bat` | Better `cat` | `bat` | `bat` | `cat` | guards in `.aliases` |
| `eza` | Better `ls` | `eza` | cargo build | `ls`, `ll`, `lt`, `ldir`, `lld` | guards in `.aliases` |
| `htop` | Process monitor | `htop` | `htop` | — | `fedora`/`debian` role |
| `btop` | Better top | `btop` | `btop` | — | `fedora`/`debian` role |
| `jq` | JSON processor | `jq` | `jq` | — | `fedora`/`debian` role |
| `colordiff` | Colored diff | `colordiff` | `colordiff` | `diff` | guards in `.aliases` |
| `fd` | Fast find | `fd-find` | `fd-find` | — | `fedora`/`debian` role |
| `fastfetch` | System info | `fastfetch` | `fastfetch` (23.10+) | — | `fedora`/`debian` role |
| `curl` | HTTP client | `curl` | `curl` | — | prerequisite |

## Desktop / Development Tools (desktop + laptop)

| Tool | Purpose | Fedora pkg | Debian pkg | Alias/Function | Notes |
|------|---------|-----------|------------|----------------|-------|
| `code` | VS Code | MS repo | MS repo | `edit_*` aliases | `vscode.yml` task |
| `ghostty` | Terminal emulator | COPR | — | `edit_ghostty` | Fedora only currently |
| `cargo` / `rustup` | Rust toolchain | `rust`/`cargo` | via rustup script | — | `fedora`/`debian` role |
| `node` / `npm` | Node.js | `nodejs` | `nodejs` + `npm` | `npmr` | `fedora`/`debian` role |
| `python3` / `pip` | Python | `python3-pip` | `python3-pip` | — | `fedora`/`debian` role |
| `docker` | Containers | manual | manual | `dbp` (`docker_build_publish`) | not in Ansible yet |
| `kubectl` | Kubernetes | manual | manual | `k` | not in Ansible yet |
| `duf` | Better df | `duf` | `duf` (22.04+) | — | `fedora`/`debian` role |
| `iotop` | I/O monitor | `iotop` | `iotop` | — | `fedora`/`debian` role |
| `pavucontrol` | Audio control | `pavucontrol` | `pavucontrol` | — | desktop/laptop only |
| `vlc` | Media player | `vlc` | `vlc` | — | desktop/laptop only |
| `wireguard` | VPN | `wireguard-tools` | `wireguard-tools` | — | desktop/laptop only |
| `tailscale` | VPN mesh | `tailscale.yml` | — | `tsu-home`, `tsd`, `tss` | Fedora only currently |
| `vivaldi` | Browser | `vivaldi.yml` | — | — | Fedora only currently |
| `espanso` | Text expander | — | — | `edit_espanso` | config in `private_dot_config/espanso` |
| `xremap` | Key remapper | cargo + systemd | cargo + systemd | — | `apps/xremap.yml` |
| `1password` | Password manager | `1password.yml` | `1password.yml` | — | both distros |
| `op` | 1Password CLI | `1password.yml` | `1password.yml` | — | required for secrets |

## Desktop-Only (gaming / creative)

| Tool | Purpose | Fedora | Debian | Notes |
|------|---------|--------|--------|-------|
| OBS Studio | Screen recording | Flatpak | Flatpak | `machine_type == 'desktop'` |
| Kdenlive | Video editor | Flatpak | Flatpak | `machine_type == 'desktop'` |

## Flatpak Apps (desktop + laptop)

| App | Flatpak ID | Notes |
|-----|-----------|-------|
| Discord | `com.discordapp.Discord` | both desktop+laptop |
| Obsidian | `md.obsidian.Obsidian` | both desktop+laptop |
| Spotify | `com.spotify.Client` | both desktop+laptop |
| OBS Studio | `com.obsproject.Studio` | desktop only |
| Kdenlive | `org.kde.kdenlive` | desktop only |

## GNOME Extensions (desktop + laptop)

| Extension | ID | Purpose |
|-----------|----|---------|
| Blur my Shell | `blur-my-shell@aunetx` | Background blur |
| Quick Settings Tweaks | `quick-settings-tweaks@qwreey` | Audio device selector |
| Caffeine | `caffeine@patapon.info` | Prevent sleep |
| Activate Window By Title | `activate-window-by-title@lucaswerkmeister.de` | Required by `focus-or-run.sh` |

## Tools NOT in Ansible (manual installs)

These are used (aliases exist) but not yet automated:

| Tool | Where to install | Alias |
|------|-----------------|-------|
| `docker` | https://docs.docker.com/engine/install/ | `dbp` |
| `kubectl` | https://kubernetes.io/docs/tasks/tools/ | `k` |
| `nvm` | https://github.com/nvm-sh/nvm | NVM_DIR in `.bashrc` |
| `gvm` | https://github.com/moovweb/gvm | gvm init in `.bashrc` |
| `bun` | https://bun.sh | PATH in `.bashrc` |

> **Note:** Consider adding these to Ansible or removing the stale PATH/alias entries.
