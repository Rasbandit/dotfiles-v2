# Claude Instructions for this Repo

## CRITICAL: Git Workflow Override

**Work directly on `main`.** This repo does NOT use feature branches — override the global CLAUDE.md rule. Commit directly to main with conventional commits.

## CRITICAL: Never Rewrite Files Containing Special Characters

Files in this repo contain Nerd Font / Powerline Unicode glyphs (e.g. starship.toml).
These appear invisible or as empty boxes in diffs and text but are real characters.

**NEVER use the Write tool on these files.** It will silently drop all special characters.

Instead:
- Use the **Edit tool** for targeted changes
- If Edit fails to match due to special characters, use **Python** to do the replacement:
  ```python
  content = open(filepath).read()
  content = content.replace(old, new)
  open(filepath, 'w').write(content)
  ```
- Inspect exact bytes first if needed: `repr(line)` in Python shows `\ue0b0` etc.

Files known to contain special characters:
- `private_dot_config/starship.toml`

---

## Architecture Overview

This repo is a **personal machine provisioning system** with two layers:
1. **Chezmoi** — manages dotfiles as templates, applies on every change
2. **Ansible** — installs packages and configures system, runs once per machine (or on feature additions)

**Bootstrap:** `curl -sL https://s.ras.band/setup | bash` runs `bootstrap.sh`, which detects the machine type, prompts for features, installs chezmoi + ansible, and applies everything.

## Machine Types

Stored in `~/.config/chezmoi/machine-type`. Valid values: `workstation`, `server`, `temporary`.
- `workstation` — full desktop/laptop setup with GUI, GNOME, apps
- `server` — headless, no GUI, minimal features
- `temporary` — ephemeral SSH sessions: shallow clone, copy configs, terminal tools only, no chezmoi

## Feature System

14 selectable features configured during bootstrap via checkbox UI:
- Core: `terminal`, `1password`, `auto-sync`
- Desktop: `vscode`, `browser`, `gnome`, `openbox`, `claude`, `japanese`, `apps`
- Gaming: `gaming-desktop`, `gaming-laptop`
- Server: `vpn`, `dev-tools`

Each feature maps to one or more Ansible role tags. Delta mode on updates means only newly selected features are run.

---

## File Naming Conventions (Chezmoi)

| Prefix | Meaning | Example |
|--------|---------|---------|
| `dot_` | Becomes `.` in `~` | `dot_bashrc` → `~/.bashrc` |
| `private_` | Mode 600 | `private_dot_bash_secrets.tmpl` |
| `private_dot_` | `.` in `~` + mode 600 | `private_dot_config/` → `~/.config/` |
| `executable_` | Gets +x bit | `executable_focus-or-run.sh` |
| `.tmpl` suffix | Go template | `dot_gitconfig.tmpl` → `~/.gitconfig` |
| `run_` prefix | Runs after `chezmoi apply` | `run_after_install-packages.sh.tmpl` |
| `run_once_` | Runs once per machine | One-time setup scripts |

**When creating new managed files**, use the correct prefix combination. Examples:
- Config file: `private_dot_config/appname/config`
- Executable script: `private_dot_local/private_bin/executable_myscript.sh`
- Templated secret: `private_dot_config/appname/private_config.tmpl`

## Template Patterns

### Secret Handling (3-tier fallback)

Always use this pattern in `.chezmoi.toml.tmpl` for secrets:
```toml
{{ if lookPath "op" -}}
    mySecret = {{ onepasswordRead "op://Personal/Item/field" | quote }}
{{ else -}}
    mySecret = {{ promptStringOnce . "mySecret" "Enter secret:" | quote }}
{{ end -}}
```

Then in template files:
```bash
export MY_SECRET={{ .mySecret }}
```

### Conditional Content by Feature

Use `.chezmoiignore.tmpl` to exclude files when features are not enabled. Check existing patterns in that file before adding new conditionals.

### Machine-Type Conditionals

In `.tmpl` files:
```
{{ if eq .machineType "workstation" }}
# desktop-only config
{{ end }}
```

---

## Ansible Patterns

### Adding a New Role

1. Create `ansible/roles/<rolename>/tasks/main.yml`
2. Add the role to `ansible/setup.yml` with a tag matching the feature name
3. Add the feature to `bootstrap.sh`:
   - Add to `ALL_FEATURES` array
   - Add default for each machine type in the defaults section
   - Add description in the feature descriptions
4. Tag pattern: role tag must match the feature name from bootstrap

### Role Structure

```
ansible/roles/<name>/
├── tasks/
│   └── main.yml          # main task file
├── handlers/              # optional
│   └── main.yml
├── files/                 # optional static files
└── templates/             # optional Jinja2 templates
```

### Existing Roles Reference

- `base` — always runs: dirs, cron, bash_secrets
- `terminal` — CLI tools: starship, fzf, zoxide, bat, eza, ripgrep, btop, fd, ghostty, gh
- `fedora` — DNF config, RPM Fusion, COPR repos, Flathub, AMD GPU
- `debian` — apt setup, Flathub, gh CLI
- `1password` — op CLI + git signing
- `vscode` — Microsoft repo + Dracula Pro theme
- `browser` — Vivaldi (Fedora only)
- `vpn` — Tailscale + WireGuard
- `dev-tools` — Docker, Node, Python, Rust, K8s
- `gnome` — extensions + keybindings
- `openbox` — window manager
- `claude` — Claude AI tools
- `japanese` — fcitx5
- `apps` — xremap, fonts
- `gaming-desktop` / `gaming-laptop` — OBS, Kdenlive

### OS-Specific Tasks

Use `when` conditionals for OS-specific tasks:
```yaml
- name: Install package (Fedora)
  dnf:
    name: mypackage
  when: ansible_distribution == "Fedora"
```

---

## Shell Configuration

### Alias Conventions (dot_aliases)

- All aliases guard on tool existence: `command -v tool &>/dev/null && alias ...`
- Chezmoi wrappers: `dots_*` prefix
- Edit shortcuts: `edit_*` prefix
- Group related aliases with comments

### Adding New Aliases

Add to `dot_aliases` in the appropriate section. Always guard with `command -v`:
```bash
# Tool Name
command -v mytool &>/dev/null && alias mt='mytool --flag'
```

### PATH Order (dot_bashrc)

1. `~/.bun/bin`
2. `~/.cargo/bin`
3. `~/.local/bin` (user scripts, chezmoi, starship)
4. `~/.krew/bin`
5. NVM / GVM (lazy-loaded)

---

## Key Scripts

- `auto-add-push.sh` — hourly cron: re-add → commit → rebase → apply → push. Watches `~/.claude/commands`.
- `focus-or-run.sh` — Wayland GNOME app switcher: WM class via DBus → title fallback → launch.
- `bootstrap.sh` — ~973 lines: full machine provisioning from zero.

## 1Password Integration

- Git signing: conditional in `dot_gitconfig.tmpl` (only if `op` CLI present)
- Secrets: resolved once at `chezmoi init`, stored in `~/.config/chezmoi/chezmoi.toml`
- Desktop: prompts user to open 1Password app
- Server: requires Service Account token

---

## Common Tasks

| Task | Command |
|------|---------|
| Preview changes | `dots_diff` |
| Apply dotfiles | `dots_apply` |
| Pull + apply | `dots_update` |
| Edit managed file | `dots_edit ~/.bashrc` |
| Add new file | `dots_add ~/.config/app/config` |
| Open source dir | `dots_cd` |
| Show active features | `dots_features` |
| Run ansible | `dots_ansible` |
| Debug template vars | `chezmoi data` |

## Known Issues

- `starship.toml` has invisible Nerd Font glyphs — **never Write, only Edit or Python**
- Nextcloud dependency for Dracula Pro theme + fonts (single point of failure)
- Stale PATH entries for docker/kubectl/nvm/gvm/bun (harmless, guarded)
- gnome-extensions-cli uses `pip --break-system-packages`
- No Arch Linux role; Tailscale/Vivaldi are Fedora-only
