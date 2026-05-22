# Onboarding

First-run setup flow. Triggered by SKILL.md when `~/.engram/skill-config.json` does not exist. Run this flow completely before returning control to SKILL.md for intent classification.

---

## Step 1: Probe

Detect backends silently — no output to the user yet.

**IMPORTANT: Never probe or use the Obsidian CLI.** It triggers Obsidian's Electron process which crash-loops and causes OOM via coredump cascades.

### Engram MCP

```
mcp__engram__search_notes(query="test", limit=1)
```

- Returns a list (empty or populated) → Engram is connected (`engram = true`)
- Tool does not exist or throws an error → not available (`engram = false`)

### Filesystem fallback

Check common vault locations:

```bash
ls ~/Obsidian\ Vault/.obsidian 2>/dev/null || ls ~/Documents/Obsidian/*/.obsidian 2>/dev/null
```

If found: `filesystem = true`, record the vault path.

### Vault path — manual fallback

If `filesystem` is `false` **and** `engram` is `false`, ask the user:

```
AskUserQuestion: "I couldn't auto-detect your Obsidian vault. Where is it located? (e.g., ~/Documents/Obsidian/MyVault)"
```

Expand the provided path (resolve `~` to the home directory). Treat this as the filesystem path for the rest of the flow.

### Determine tier

| Condition | Tier |
|-----------|------|
| `engram = true` | **Tier 2 (Full)** |
| `engram = false` | **Tier 1 (Files)** |

---

## Step 2: Report

Show a summary of what was found. Use ✓ for available, ✗ for unavailable.

```
Engram detected:
  ✓ Engram MCP — connected
  ✓ Vault filesystem — /home/user/Obsidian Vault

Running in Tier 2 (Full) mode.
```

Adjust each line to match actual probe results.

---

## Step 3: Advocate

If Engram MCP is missing:
```
Engram MCP adds semantic search, auto-folder placement, and safe writes that bypass Obsidian's process. Setup: https://engram.dev/setup
```

If present, skip this step entirely.

---

## Step 4: Multi-vault default

The Engram MCP manages vaults server-side. If `engram = true`, use `"Personal"` as the default vault (the standard config).

If only filesystem is available, detect vaults from the filesystem path.

If multiple vaults exist, ask the user which should be the default.

---

## Step 5: Save config

Write `~/.engram/skill-config.json` using the schema below.

```json
{
  "tier": 2,
  "defaultVault": "Personal",
  "vaults": {
    "Personal": { "path": "/home/user/Obsidian Vault" }
  },
  "backends": {
    "cli": false,
    "engram": true,
    "filesystem": true
  },
  "topicScopes": {}
}
```

**Note:** `backends.cli` is always `false`. The Obsidian CLI is permanently retired.

### Field values

| Field | Value |
|-------|-------|
| `tier` | 1 or 2 (from Step 1 determination) |
| `defaultVault` | Name chosen in Step 4, or `"Personal"` |
| `backends.cli` | Always `false` |
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
