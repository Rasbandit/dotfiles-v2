# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/) + [Ansible](https://ansible.com/).

## Quick Start (New Machine)

```bash
curl -sL https://bit.ly/bandit-dotfiles-init | bash
```

Or manually:

```bash
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize and apply
chezmoi init --apply Rasbandit/dotfiles
```

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
├── .chezmoiignore          # Files to ignore
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
        ├── base/           # Cross-platform basics
        ├── fedora/         # Fedora-specific
        ├── debian/         # Debian/Ubuntu-specific
        └── apps/           # Apps (xremap, fonts, etc.)
```

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

Set during init, used by ansible for conditional installs:
- `desktop-gaming` - Full setup with gaming packages
- `laptop` - Standard setup without gaming extras
- `server` - Minimal server setup
