---
description: Add a dotfile or config file to the chezmoi-managed dotfiles repo. Use when user says "add this to chezmoi", "track this dotfile", or "manage this config with chezmoi".
argument-hint: <file path or description of what to add>
---

# Add Dotfile to Chezmoi

When adding new files or configs to this chezmoi-managed dotfiles repo, follow these conventions.

## Chezmoi Naming Conventions

| Prefix/Suffix | Meaning |
|---|---|
| `dot_` | Maps to `.` in home dir (e.g. `dot_bashrc` → `~/.bashrc`) |
| `private_` | Sets 600 permissions — **required for files containing secrets** |
| `executable_` | Sets +x permission |
| `.tmpl` | Go template — processed by chezmoi on apply |
| `run_after_` | Script that runs after `chezmoi apply` |
| `run_once_after_` | Runs once per machine (tracked by checksum) |

Combine prefixes as needed: `private_dot_config/private_myapp.conf.tmpl`

## 3-Tier Secret Pattern

When a config file needs API keys or secrets, use this **3-tier fallback** pattern.

**Important:** `promptStringOnce` only works in `.chezmoi.toml.tmpl` (the config template). Regular `.tmpl` files read the stored data via `.dataKeyName`.

### Step 1: Add data key to `.chezmoi.toml.tmpl`

Add the key in **both** branches of `.chezmoi.toml.tmpl`:

**`op` branch** (reads from 1Password once during `chezmoi init`):
```
    <camelCaseKeyName> = {{ onepasswordRead "op://Personal/<Item>/<field>" | quote }}
```

**`else` branch** (prompts user once during `chezmoi init`):
```
    <camelCaseKeyName> = {{ promptStringOnce . "<camelCaseKeyName>" "<Human-readable prompt> (Enter to skip)" | quote }}
```

### Step 2: Use data variable in target template

The target template is simple — just read the data variable. No `op`/`else` branching needed:

```
"apiKey": "{{"{{"}} if (get . "<camelCaseKeyName>") {{"}}"}}{{"{{"}} .<camelCaseKeyName> {{"}}"}}{{"{{"}} else {{"}}"}}REPLACE_ME{{"{{"}} end {{"}}"}}",
```

### How the tiers work:
1. **Tier 1 — 1Password (`op` CLI available):** During `chezmoi init`, pulls secret from 1Password and stores in `chezmoi.toml`. Never calls `op` during `chezmoi apply`.
2. **Tier 2 — Interactive prompt (no `op`):** During `chezmoi init`, asks the user once, stores answer in `chezmoi.toml`. Never asks again.
3. **Tier 3 — Placeholder (`REPLACE_ME`):** If user presses Enter without input, stores empty string → `{{ if .key }}` is false → outputs `REPLACE_ME`.
4. **To refresh secrets:** Re-run `chezmoi init` — it will re-read from 1Password or re-prompt.

### Rules for data keys:
- Must be **camelCase** and unique across all templates (e.g. `openaiApiKey`, `githubToken`)
- Prompt string should name the secret and include `(Enter to skip)`
- The stored value persists in `chezmoi.toml` — user only sees the prompt during `chezmoi init`
- `chezmoi apply` never touches `op` — all secrets come from local config

### 1Password vault structure:
- AI API keys: `op://Personal/AI API Keys/<provider>` (openai, anthropic, mistral, xai, gemini)
- Other secrets: `op://Personal/<ItemName>/<field>`

## File Placement

- Config files go under the matching chezmoi path (e.g. `private_dot_config/private_myapp/`)
- Scripts go in `dot_local/bin/` (maps to `~/.local/bin/`)
- Shell env/secrets go in `private_dot_bash_secrets.tmpl`

## Template Variables Available

- `{{ .hostname }}` — machine hostname
- `{{ .machineType }}` — `desktop`, `laptop`, `server`, or `temporary`
- `{{ .email }}` — user email
- Check all: `chezmoi data`

## Checklist for Adding a New Dotfile

1. Determine the target path in `$HOME`
2. Create the chezmoi source file with correct prefixes (`dot_`, `private_`, `.tmpl`)
3. If it contains secrets → use `private_` prefix + 3-tier template pattern
4. If it needs conditional logic (machine type, OS) → use `.tmpl` suffix
5. Test with `chezmoi diff` and `chezmoi apply --dry-run`
6. Add to git on the current feature branch

$ARGUMENTS
