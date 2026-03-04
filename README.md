# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/) + [Ansible](https://ansible.com/).

## Quick Start (New Machine)

```bash
curl -sL https://s.ras.band/setup | bash
```

The script prompts for machine type and whether to install terminal tools:

| Type | What it does |
|------|-------------|
| `temporary` | Downloads config files directly, installs starship + ~8 tools. No git auth, no ansible. |
| `server` | Installs chezmoi, pre-creates config non-interactively, optionally runs ansible `--tags terminal`. |
| `laptop` | Full chezmoi + ansible setup. No gaming packages. |
| `desktop` | Full chezmoi + ansible setup with gaming packages. |

## Daily Usage

| Command | Description |
|---------|-------------|
| `dots_diff` | See what would change |
| `dots_apply` | Apply dotfile changes |
| `dots_update` | Pull and apply updates from remote |
| `dots_edit ~/.bashrc` | Edit a managed file |
| `dots_add ~/.some/file` | Add a new file to be managed |
| `dots_cd` | cd to chezmoi source directory |

## Structure

```
.
├── .chezmoi.toml.tmpl      # Machine-specific config (hostname, type, email)
├── .chezmoiignore          # Files to ignore (ansible/, bootstrap.sh are NOT dotfiles)
├── TOOLS.md                # CLI tool runbook — update when adding new tools
├── bootstrap.sh            # One-liner setup script
├── dot_*                   # Dotfiles (dot_ becomes .)
├── private_dot_*           # Private dotfiles (600 permissions)
├── private_dot_config/     # ~/.config files
│   ├── ghostty/
│   ├── starship.toml
│   └── xremap/
└── ansible/                # Software installation
    ├── setup.yml           # Main playbook
    └── roles/
        ├── base/           # Cross-platform basics (starship, cron sync)
        ├── fedora/         # Fedora-specific packages
        ├── debian/         # Debian/Ubuntu-specific packages
        ├── apps/           # Cross-platform apps (xremap, fonts, japanese)
        └── gnome/          # GNOME settings + extensions (desktop/laptop only)
```

### machine_type

Persisted to `~/.config/chezmoi/machine-type` by bootstrap (and chezmoi config).
Ansible reads this file to apply conditional installs. Valid values:

| Value | Description |
|-------|-------------|
| `desktop` | Full setup + gaming packages (OBS, Kdenlive) |
| `laptop` | Full setup, no gaming extras |
| `server` | Terminal tools only, no desktop/GNOME |

## 1Password Integration

Secrets are pulled from 1Password. Edit `~/.local/share/chezmoi/private_dot_bash_secrets.tmpl`:

```bash
# Example: API key from 1Password
export MY_API_KEY={{ onepasswordRead "op://Personal/MyAPI/credential" }}
```

Then `chezmoi apply` will populate the actual values.

## Adding New Dotfiles

```bash
# Add an existing file
chezmoi add ~/.config/something/config.toml

# Add as a template (for machine-specific values)
chezmoi add --template ~/.config/something/config.toml
```

## Running Ansible Manually

```bash
cd $(chezmoi source-path)/ansible
ansible-playbook setup.yml --ask-become-pass

# Run specific tags only
ansible-playbook setup.yml --ask-become-pass --tags "apps"
```

## Machine Types

Set during bootstrap, used by chezmoi and ansible for conditional installs:
- `desktop` - Full setup with gaming packages
- `laptop` - Full setup without gaming extras
- `server` - Persistent server, no desktop apps
- `temporary` - Throwaway SSH session, minimal setup (no chezmoi/ansible)
