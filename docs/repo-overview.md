# Chezmoi Dotfiles — Quick Reference

## Architecture

Two layers: **chezmoi** (dotfiles/templates) + **Ansible** (packages/system config).
Bootstrap: `curl -sL https://s.ras.band/setup | bash` → runs `bootstrap.sh`

## Machine Types

Stored in `~/.config/chezmoi/machine-type`

| Value | Use |
|-------|-----|
| `workstation` | Full desktop/laptop, GUI, GNOME, all apps |
| `server` | Headless, no GUI, minimal features |
| `temporary` | Ephemeral SSH — copy configs only, no chezmoi/ansible |

## Features (14 total)

| Group | Features |
|-------|----------|
| Core | `terminal`, `1password`, `auto-sync` |
| Desktop | `vscode`, `browser`, `gnome`, `openbox`, `claude`, `japanese`, `apps` |
| Gaming | `gaming-desktop`, `gaming-laptop` |
| Server | `vpn`, `dev-tools` |

Delta mode: only newly selected features run on update.

## Common Operations

| Task | Command |
|------|---------|
| Preview changes | `dots_diff` |
| Apply dotfiles | `dots_apply` |
| Pull + apply | `dots_pull` |
| Push changes | `dots_push` |
| Edit managed file | `dots_edit ~/.bashrc` |
| Add file to tracking | `dots_add ~/.config/app/config` |
| Re-add all tracked | `dots_add` (no args) |
| Remove tracking | `dots_remove ~/.config/app/config` |
| Show active features | `dots_status` |
| Run provisioning | `dots_provision` |
| Debug template vars | `chezmoi data` |
| Open source dir | `edit_dots` |

## Ansible Roles

| Role | Purpose |
|------|---------|
| `base` | dirs, cron sync, bash_secrets — always runs |
| `terminal` | starship, fzf, zoxide, bat, eza, ripgrep, btop, fd, ghostty, gh |
| `fedora` | DNF (20 parallel), RPM Fusion, COPR, Flathub, AMD GPU |
| `debian` | apt, Flathub, gh CLI |
| `1password` | op CLI + git signing |
| `vscode` | Microsoft repo + Dracula Pro theme |
| `browser` | Vivaldi (Fedora only) |
| `vpn` | Tailscale + WireGuard |
| `dev-tools` | Docker, Node, Python, Rust, K8s |
| `gnome` | extensions, keybindings (CapsLock = Ctrl+Shift+Alt) |
| `openbox` | window manager config |
| `claude` | Claude AI tools |
| `japanese` | fcitx5 input method |
| `apps` | xremap (cargo + systemd), fonts |
| `gaming-desktop` / `gaming-laptop` | OBS, Kdenlive (Flatpak) |

## Key Files

| File | Purpose |
|------|---------|
| `.chezmoi.toml.tmpl` | Bootstrap config + secret prompts |
| `dot_aliases` | ~246 aliases with tool guards |
| `dot_bashrc` | PATH (bun/cargo/local/krew/nvm/gvm), history 100k |
| `dot_bash_functions` | Helper functions (decompress_all, etc.) |
| `private_dot_bash_secrets.tmpl` | 1Password env vars |
| `private_dot_continue/private_config.json.tmpl` | LLM configs (GPT-4, Grok, Claude, etc.) |
| `ansible/setup.yml` | Main playbook (2-phase: OS detect → roles by tag) |
| `bootstrap.sh` | ~973 line full machine setup |
| `run_after_install-packages.sh.tmpl` | Post-apply hook |
| `executable_auto-add-push.sh` | Hourly sync cron |
| `executable_focus-or-run.sh` | Wayland GNOME app switcher |
| `TOOLS.md` | CLI tool inventory — update when adding tools |

## 1Password Auth

- Secrets resolved once at `chezmoi init` → stored in `~/.config/chezmoi/chezmoi.toml`
- Desktop: prompts to open 1Password app, waits for `op vault list`
- Server: requires `OP_SERVICE_ACCOUNT_TOKEN` env var
- Git signing: SSH key via op-ssh-sign, conditional on `op` CLI presence

## Auto-Sync

`executable_auto-add-push.sh` runs hourly via cron.
Flow: re-add → commit → pull/rebase → apply → push.
Also watches `~/.claude/commands`. Notifies on conflicts via `notify-send`.
