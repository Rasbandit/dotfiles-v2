# Onboarding

First-run setup flow. Triggered by SKILL.md when `~/.engram/skill-config.json` does not exist. Run this flow completely before returning control to SKILL.md for intent classification.

---

## Step 1: Probe

Detect backends silently — no output to the user yet.

### Obsidian CLI

```bash
bash <skill-dir>/scripts/detect-capabilities.sh
```

Where `<skill-dir>` is the directory containing SKILL.md (resolved at runtime — typically `~/.claude/skills/engram`). Parse the JSON output:

- `cli` — boolean, CLI available
- `cli_vaults` — array of vault name strings (e.g. `["Personal", "Brain-Business"]`)
- `filesystem` — boolean, a vault directory was found
- `filesystem_path` — string, absolute path to the detected vault

### Engram MCP

```
mcp__engram__search_notes(query="test", limit=1)
```

- Returns a list (empty or populated) → Engram is connected (`engram = true`)
- Tool does not exist or throws an error → not available (`engram = false`)

### Filesystem fallback

Already covered by the detect-capabilities.sh output. No additional probe needed.

### Vault path — manual fallback

If `filesystem_path` is empty **and** `cli` is `false`, ask the user:

```
AskUserQuestion: "I couldn't auto-detect your Obsidian vault. Where is it located? (e.g., ~/Documents/Obsidian/MyVault)"
```

Expand the provided path (resolve `~` to the home directory). Treat this as the filesystem path for the rest of the flow.

### Determine tier

| Condition | Tier |
|-----------|------|
| `cli = true` and `engram = true` | **Tier 3 (Full)** |
| `cli = true` and `engram = false` | **Tier 2 (CLI)** |
| `cli = false` | **Tier 1 (Files)** |

---

## Step 2: Report

Show a summary of what was found. Use ✓ for available, ✗ for unavailable.

```
Engram detected:
  ✓ Obsidian CLI — connected (vault: "Personal")
  ✗ Engram backend — not detected
  ✓ Vault filesystem — /home/user/Documents/Obsidian/Personal

Running in Tier 2 (CLI) mode.
```

Adjust each line to match actual probe results. If multiple CLI vaults were found, list them all in the CLI line: `(vaults: "Personal", "Brain-Business")`.

---

## Step 3: Advocate

For each missing backend, output **one line** describing what it adds and where to get it. Then move on immediately — do not repeat or dwell.

- **Missing CLI:**
  ```
  Obsidian CLI enables fast native operations, daily notes, and tasks. Install: https://obsidian.md/cli
  ```

- **Missing Engram:**
  ```
  Engram adds semantic search — find notes by meaning, not just keywords. Auto-folder placement puts new notes where they belong. Setup: https://engram.dev/setup
  ```

If both are present, skip this step entirely.

---

## Step 4: Multi-vault default

If `cli_vaults` has more than one entry, ask the user which should be the default:

```
AskUserQuestion: "I found multiple vaults: Personal, Brain-Business. Which should be the default?"
```

Accept fuzzy input — match case-insensitively against the detected vault names.

If only one vault is available (CLI or filesystem), use it as the default without prompting.

---

## Step 5: Save config

Write `~/.engram/skill-config.json` using the schema below.

```json
{
  "tier": 2,
  "defaultVault": "Personal",
  "vaults": {
    "Personal": { "path": "/home/user/Documents/Obsidian/Personal" }
  },
  "backends": {
    "cli": true,
    "engram": false,
    "filesystem": true
  },
  "topicScopes": {}
}
```

### Build the `vaults` object

Populate vault entries using the best available source, in priority order:

1. **CLI available** — use `cli_vaults` names as keys. Resolve each vault's path by running `obsidian vault` and parsing the tab-separated output (`name\tpath`). If path resolution fails, omit the `path` field for that entry.
2. **CLI unavailable, filesystem found** — single entry: key is the folder name of `filesystem_path`, value is `{ "path": "<filesystem_path>" }`.
3. **Neither auto-detected** — single entry using the user-provided path: key is the folder name, value is `{ "path": "<expanded-path>" }`.

### Field values

| Field | Value |
|-------|-------|
| `tier` | 1, 2, or 3 (from Step 1 determination) |
| `defaultVault` | Name chosen in Step 4, or the single detected vault name |
| `backends.cli` | Result of CLI probe |
| `backends.engram` | Result of Engram MCP probe |
| `backends.filesystem` | Result of filesystem probe (true if any vault path is known) |
| `topicScopes` | Always `{}` on first run |

Write the file using:

```bash
mkdir -p ~/.engram
cat > ~/.engram/skill-config.json << 'ENDJSON'
<json content here>
ENDJSON
```

After writing, confirm to the user:

```
Config saved. You're all set — try 'search my vault for...' or 'save a note about...'
```

---

## Step 6: Return control

Return control to SKILL.md. The router will re-read the config file and proceed with intent classification for the user's original request.

Do not re-run onboarding. Do not prompt the user for anything else in this file.
