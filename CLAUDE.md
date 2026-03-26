# Claude Instructions for this Repo

> For repo structure, commands, roles, and key files — read `docs/repo-overview.md`.

## CRITICAL: Git Workflow Override

**Work directly on `main`.** No feature branches — override the global CLAUDE.md rule.

## CRITICAL: Never Rewrite Files With Special Characters

Files contain Nerd Font/Powerline Unicode glyphs that appear invisible in diffs.
**NEVER use the Write tool on these files** — it silently drops all special characters.

Use **Edit** for targeted changes. If Edit fails to match due to special characters:
```python
content = open(filepath).read()
content = content.replace(old, new)
open(filepath, 'w').write(content)
```

Files: `private_dot_config/starship.toml`

## CRITICAL: Never Hardcode Home Directory Paths

**NEVER** use literal `/home/<username>/` in any managed file. These break when syncing between machines with different usernames.

**Chezmoi templates** (`.tmpl` files): use `{{ .chezmoi.homeDir }}` for full paths, `{{ .chezmoi.username }}` for just the username.
```
ExecStart={{ .chezmoi.homeDir }}/.local/bin/my-script
```

**Ansible templates** (`.j2` files): use `{{ ansible_env.HOME }}` or `{{ lookup('env', 'HOME') }}`.

**Shell scripts** (non-template): use `$HOME` or `~`.

If a file contains a hardcoded home path, convert it to a `.tmpl` template first (`git mv file file.tmpl`), then replace the path. Also add appropriate entries to `.chezmoiignore.tmpl` if the file is feature-gated.

**Files that should NOT be templated:** auto-generated files with volatile content — add these to `.chezmoiignore.tmpl` instead. Currently ignored:
- `.claude/plugins/installed_plugins.json` — timestamps, SHAs change on every plugin update
- `.claude/plugins/known_marketplaces.json` — timestamps, hardcoded paths, auto-updated

---

## File Naming (when creating new managed files)

| Prefix | Result | Example |
|--------|--------|---------|
| `dot_` | `.` in `~` | `dot_bashrc` → `~/.bashrc` |
| `private_dot_` | `.` in `~` + 600 | `private_dot_config/` → `~/.config/` |
| `executable_` | +x bit | `executable_myscript.sh` |
| `.tmpl` suffix | Go template | `dot_gitconfig.tmpl` |
| `run_` / `run_once_` | Runs after apply / once | post-apply scripts |

New file examples:
- Config: `private_dot_config/appname/config`
- Script: `private_dot_local/private_bin/executable_myscript.sh`
- Secret: `private_dot_config/appname/private_config.tmpl`

## Template Patterns

### Secrets (3-tier fallback)
```toml
{{ if lookPath "op" -}}
    mySecret = {{ onepasswordRead "op://Personal/Item/field" | quote }}
{{ else -}}
    mySecret = {{ promptStringOnce . "mySecret" "Enter secret:" | quote }}
{{ end -}}
```
Then in templates: `export MY_SECRET={{ .mySecret }}`

### Machine-type conditionals
```
{{ if eq .machineType "workstation" }}
# desktop-only config
{{ end }}
```

### Feature conditionals
Use `.chezmoiignore.tmpl` to exclude files when a feature is disabled. Check existing patterns first.

---

## Ansible: Adding a New Role

1. Create `ansible/roles/<name>/tasks/main.yml`
2. Add to `ansible/setup.yml` with tag matching feature name
3. Add feature to `bootstrap.sh`: `ALL_FEATURES` array, defaults per machine type, description
4. Role tag must match the feature name exactly

OS-specific tasks:
```yaml
when: ansible_distribution == "Fedora"
```

---

## Shell: Adding Aliases

Always guard with `command -v`:
```bash
command -v mytool &>/dev/null && alias mt='mytool --flag'
```
Prefixes: `dots_*` for chezmoi wrappers, `edit_*` for edit shortcuts.

---

## Known Issues

- `starship.toml` — Nerd Font glyphs: never Write, only Edit or Python
- Nextcloud: single point of failure for fonts + Dracula Pro theme
- `gnome-extensions-cli`: uses `pip --break-system-packages`
- Tailscale/Vivaldi: Fedora-only; no Arch role

## Life OS
project: dotfiles
goal: self-reliance
value: self-reliance
