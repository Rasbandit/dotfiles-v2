---
name: engram
description: >
  Trigger for ANY interaction with an Obsidian vault, notes, or personal knowledge base — even when the user doesn't say "vault" or "engram" explicitly.

  Search operations: "find notes about", "search vault", "search my notes", "what do I know about", "do I have notes on", "have I written about", "look up in my notes", "recall anything about".

  Read operations: "read my note on", "show me my note", "open note", "pull up", "what does my note say about", "show me what I wrote about".

  Create operations: "save this", "create a note", "remember this", "engram this", "document this", "write this down", "note this", "keep a record of", "jot this down", "make a note".

  Update operations: "append to", "update my note", "add to my note", "add this to", "edit my note", "insert into", "add a section to".

  Daily note operations: "daily note", "add to today", "what's on today", "today's note", "log to today", "morning pages", "what did I log today".

  Task operations: "my tasks", "mark done", "what's todo", "show tasks", "add a task", "complete task", "what tasks do I have", "task list".

  Browse/navigate operations: "what's in my vault", "show folders", "what tags", "list my notes", "vault structure", "what topics", "show me my knowledge base".

  Proactive/ambient: silently trigger when encountering unfamiliar terms, project names, people names, or concepts mid-conversation — check the vault before responding as if you don't know. If the user references something you're uncertain about, check the vault first.
argument-hint: <what to do with your vault>
---

# Engram — Vault Management Router

Unified skill for Obsidian vault management. Adapts to available backends and dispatches to the right reference file per operation.

---

## Step 1: Capability Detection

### First Run (no config file)

Check for `~/.engram/skill-config.json`.

If the file does **not** exist:
1. Read `references/onboarding.md`
2. Follow its first-run setup flow completely
3. **STOP** — do not proceed to intent classification until onboarding writes the config and returns control here

### Subsequent Runs (config exists)

Read `~/.engram/skill-config.json`. Then run a quick health check against what config claims is available.

**CLI check** — if `backends.cli` is `true` in config:
```bash
obsidian vault 2>/dev/null
```
If the command fails or returns a non-zero exit: set `cli_available = false`, downgrade tier.

**Engram MCP check** — if `backends.engram` is `true` in config:
```
mcp__engram__search_notes(query="health_check", limit=1)
```
If the call throws or returns an error: set `engram_available = false`, downgrade tier.

**On state change** — if detected tier differs from `config.tier`:
- Update `config.tier` and the relevant `backends.*` field
- Notify the user **once**: e.g. `"Obsidian CLI is now available — upgraded to Tier 2."`
- Rule: **one notification per session per backend state change.** Track notified state changes in-session; never repeat the same notification.

**Resolved tier** — set working tier for this session:
- `filesystem_only` → Tier 1
- `cli` (no engram) → Tier 2
- `cli + engram` → Tier 3

---

## Step 2: Tier Reference

| Tier | Available | Experience |
|------|-----------|------------|
| **Tier 1: File-only** | Raw filesystem | Basic read/write, grep search. Functional but limited. |
| **Tier 2: CLI** | Obsidian CLI | Fast native ops, text search, daily notes, tasks, templates. Full-featured minus semantic search. |
| **Tier 3: Full** | CLI + Engram MCP | Everything in Tier 2 plus semantic search, auto-folder placement, neural reranking. |

---

## Step 3: Multi-Vault Resolution

Before classifying intent, resolve which vault to operate on.

1. Scan the user's message for a vault name (e.g. "in my Work vault", "Personal vault", "the Recipes vault")
2. If found: fuzzy-match against `config.vaults` keys (case-insensitive, partial match is fine)
3. If no vault mentioned or no match: use `config.defaultVault`
4. Store the resolved vault name and its path for use in the reference file

If the fuzzy match is ambiguous (two vaults both match), ask the user to clarify before proceeding.

---

## Step 4: Intent Classification

Map the user's request to one of 7 operation categories, then load the corresponding reference file.

| Intent | Trigger signals | Reference file |
|--------|----------------|----------------|
| **Search** | "find notes about", "search vault", "what do I know about", "do I have notes on", ambient unfamiliar terms/people/projects | `references/search.md` |
| **Read** | "read my note on", "show me", "open note", "pull up", "what does my note say" | `references/read.md` |
| **Create** | "save this", "create a note", "remember this", "engram this", "note this", "document this" | `references/create.md` |
| **Update** | "append to", "update my note", "add to my note", "edit my note", "insert into" | `references/update.md` |
| **Daily** | "daily note", "add to today", "today's note", "what's on today", "log to today" | `references/daily.md` |
| **Tasks** | "my tasks", "mark done", "what's todo", "add a task", "task list" | `references/tasks.md` |
| **Browse** | "what's in my vault", "show folders", "what tags", "vault structure", "list my notes" | `references/browse.md` |

### Classification Rules

**Ambiguous intent** — prefer the broader interpretation. When in doubt, Search is the safest fallback because it surfaces information without destructive side effects.

**Compound intent** — if the user wants to do two things (e.g. "find my note about X and add Y to it"), classify as the **action** intent (Update). The reference file handles the search-then-act flow internally.

**Vault navigation without a specific note** — if the user is exploring structure, folders, or topics without targeting a particular note, that is Browse.

**Ambient / proactive search** — when encountering an unfamiliar term, project name, or person mid-conversation, silently classify as Search without announcing it. Incorporate vault results naturally in the response.

---

## Step 5: Topic Scoping

Topic scoping biases search and placement toward relevant folders/tags. It is **soft** — never a hard filter.

- Full details: `references/scoping.md`
- Key rule: **never silently exclude results from other folders.** Surface out-of-scope results with a light label (e.g. `[outside work scope]`), but always include them.
- When a reference file needs to resolve a scope, it will load `references/scoping.md` directly. SKILL.md does not need to pre-load it.

Active scopes come from `config.topicScopes` (set during onboarding or updated by the user).

---

## Step 6: Fallback and Upsell Rules

**Never block on a missing backend.** Every operation has a fallback path. If Tier 3 is unavailable, degrade to Tier 2; if Tier 2 is unavailable, degrade to Tier 1.

**Upsell rule** — if a missing backend would meaningfully improve the result (e.g. semantic search falls back to grep), mention the upgrade path **at most once per session**, in an informational tone:
> "Semantic search isn't available — using text search instead. Install Engram MCP for better results."

Never upsell the same backend twice in one session.

**Mid-session upgrade** — if a backend becomes available after the session starts (e.g. user installs CLI mid-session), auto-detect on the next health check and upgrade silently unless the tier actually changes, in which case notify once per the rule above.

---

## Step 7: Execute

With capability tier, resolved vault, and classified intent in hand:

1. Read the reference file for the classified intent (path relative to this file's location)
2. Pass context to the reference file:
   - **`vault`**: resolved vault name
   - **`vaultPath`**: resolved vault path from config
   - **`tier`**: current working tier (1, 2, or 3)
   - **`topicScopes`**: active scopes from config (may be empty)
3. Follow the reference file's tier-appropriate instructions exactly
4. If the reference file instructs a fallback (e.g. Tier 3 step fails), follow it without re-classifying intent

---

## Config Schema (reference)

```json
{
  "tier": 2,
  "defaultVault": "Personal",
  "vaults": {
    "Personal": { "path": "/home/user/vaults/Personal" }
  },
  "backends": {
    "cli": true,
    "engram": false,
    "filesystem": true
  },
  "topicScopes": {}
}
```

Config lives at `~/.engram/skill-config.json`. It is created by `references/onboarding.md` on first run.
