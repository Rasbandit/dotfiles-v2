---
description: The user wants to back up something they just installed or configured on their machine. Use when user says "back this up", "add to dotfiles", "track this config", "save this to ansible", or "add this package to my setup".
argument-hint: <what was installed or configured>
---

The user wants to back up something they just installed or configured on their machine.
This repo uses TWO systems — figure out which one applies, then take action.

User's request: $ARGUMENTS

---

## System Overview

**chezmoi** — tracks dotfiles (config files in `~` or `~/.config/`).
**Ansible** — tracks packages, system software, Flatpaks, GNOME settings.

Repo path: `~/.local/share/chezmoi`

---

## Decision Tree

### Is it a config FILE (lives in `~` or `~/.config/`)?
→ Use **chezmoi**.

Steps:
1. `config_add <file>` — start tracking it
2. `config_edit <file>` — review/tweak if needed
3. Commit: stage in `~/.local/share/chezmoi`, then `/commit_push`

Examples: `.tmux.conf`, `~/.config/ghostty/config`, `~/.bashrc`

---

### Is it a PACKAGE or system-level install?
→ Use **Ansible**.

Determine the right role/task file:

| What | File |
|---|---|
| DNF package (Fedora) | `ansible/roles/fedora/tasks/main.yml` |
| Flatpak | `ansible/roles/fedora/tasks/main.yml` (flatpak section) |
| apt package (Debian) | `ansible/roles/debian/tasks/main.yml` |
| Font | `ansible/roles/apps/tasks/fonts.yml` |
| GNOME setting/keybinding | `ansible/roles/gnome/tasks/` |
| App with systemd service | `ansible/roles/apps/tasks/` |
| All-machine base tool | `ansible/roles/base/tasks/main.yml` |

Steps:
1. Read the relevant task file first
2. Add the package/task in the correct section
3. Commit with `/commit_push`
4. Remind user to run `dots_provision` on each machine to apply

---

### Is it BOTH (e.g. installed a tool AND it has a config file)?
→ Do both: Ansible for the package, chezmoi for the config.

---

## Key Aliases (already in `~/.aliases`)
- `config_add` — chezmoi add
- `config_edit` — chezmoi edit
- `config_apply` — chezmoi apply
- `config_sync` — chezmoi update (pull + apply)
- `config_dir` — cd into source repo
- `dots_provision` — run the full Ansible playbook

## Machine Types
Stored in `~/.config/chezmoi/machine-type`: `desktop`, `laptop`, `server`, `temporary`
Use this to scope Ansible tasks to the right machines.

## After any changes
- Commit with `/commit_push`
- Remind user: auto-sync cron runs hourly, or they can run `dots_pull` manually
- If Ansible was changed: remind user to run `dots_provision` on each machine
