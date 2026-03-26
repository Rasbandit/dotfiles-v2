---
name: work-log
description: Write one or more entries to the daily work log. Use at session start to initialize today's file, and after every meaningful action to append an entry. Trigger on "/work-log", "log this", "log my work", or "add to work log". Also triggers automatically at session start per CLAUDE.md mandate.
argument-hint: [init | <description of work done>]
---

Write to the daily work log. If `$ARGUMENTS` is `init` or empty, run the session-start procedure. Otherwise append a single entry describing the work in `$ARGUMENTS`.

## Log file location

```
1. Alignment/4. Work Log/YYYY-MM/YYYY-MM-DD.md
```

Use today's date. Never read-then-write.

---

## Step 0 — Detect write backend

Check backends in this priority order. Use the **first** that succeeds:

### 1. Obsidian CLI (preferred)

Run: `command -v obsidian` via Bash. If found, use this backend.

**Append:** `obsidian append path="1. Alignment/4. Work Log/YYYY-MM/YYYY-MM-DD.md" content="<text>" vault=Personal`

- The CLI creates the file if it doesn't exist.
- Escape double quotes in content. Use `\n` for newlines within the content value.

### 2. Engram MCP (fallback)

If Obsidian CLI is not available, check if `mcp__engram__append_to_note` is callable. If so, use it:

- `path`: `1. Alignment/4. Work Log/YYYY-MM/YYYY-MM-DD.md`
- `text`: the entry text

### 3. Filesystem (last resort)

If neither CLI nor Engram MCP is available, use `mcp__filesystem__write_file` to write directly to the vault path from `~/.engram/skill-config.json` → `vaults.<default>.path`.

Full path: `<vault_path>/1. Alignment/4. Work Log/YYYY-MM/YYYY-MM-DD.md`

Read the file first to preserve existing content, then append.

---

## Step 1 — Resolve tag slugs

**Read the current project's CLAUDE.md** (in CWD or nearest parent dir) and extract the `## Life OS` block:

```markdown
## Life OS
project: <slug>   →  #project/<slug>
goal: <slug>      →  #goal/<slug>
value: <slug>     →  #value/<slug>
```

**If no `## Life OS` block exists:** call `/lifeos-onboard` first, then proceed once it's set up.

**If no CLAUDE.md exists at all** (global/personal session with no project): use best-guess slugs and append `(untracked)` to the description.

**If working across multiple projects in one block:** use the primary project's tags.

---

## Step 2 — Get the time

Run `date +%H:%M` to get the current (end) time.

Estimate the start time by looking at when the current work block began in the conversation history (first message about this task/bug/feature). If unsure, subtract a reasonable estimate (10–20 min for a focused task, up to 60 min for a long session).

Format: `[HH:MM-HH:MM]` — e.g. `[14:05-14:35]`

---

## Step 3 — Append the entry

Use the backend selected in Step 0 to append the entry to today's log file.

Add `# YYYY-MM-DD\n\n` as a prefix **only** if this is the very first entry of the day.

Entry format:
```
[HH:MM-HH:MM] #project/<slug> #goal/<slug> #value/<slug> <Description>
```

**Description rules:**
- Past tense, one sentence, specific enough to reconstruct what happened without reading code
- Name the artifact: file, function, service, config, decision
- Include outcome or state change: "fixed", "added", "removed", "decided", "discovered", "debugged"
- Skip filler: "worked on", "made changes to", "did some", "updated things"

**Good entries:**
```
[14:00-14:30] #project/gobigger-doterra #goal/gobigger #value/self-reliance Migrated user-service.ts from Firestore to Drizzle/Postgres — session auth now fully on Supabase
[09:15-09:45] #project/open-claw-manager #goal/self-hosting #value/self-reliance Debugged Navigator cron not firing — root cause was missing CLAUDE.md Life OS block, added it
[20:00-20:20] #project/audiobook-tools #goal/self-hosting #value/self-reliance Decided to decouple audiobook-tools from ops-dispatcher — removes single point of failure
```

**Bad entries (do not write these):**
```
[14:00-14:30] #project/gobigger-doterra #goal/gobigger #value/self-reliance Worked on the database migration
[09:15-09:45] #project/open-claw-manager #goal/self-hosting #value/self-reliance Fixed bug
[20:00-20:20] #project/audiobook-tools #goal/self-hosting #value/self-reliance Made some updates
```

---

## What qualifies as loggable

**Log when a unit of work completes:**
- A file was created, edited, or deleted
- A git commit was made
- A debugging session concluded (log the root cause, not just the fix)
- A research/exploration phase finished (read files + formed understanding)
- A planning phase finished
- An architectural or design decision was reached
- Any sustained effort ≥ ~10 minutes on one thing

**Do NOT log when:**
- Answering a quick question with no file changes
- Mid-task (log at the end of the task, not every step)
- Only one or two conversation exchanges have happened

---

## Session-start procedure (`init`)

1. Read the current project's CLAUDE.md and resolve slugs (Step 1 above) — background prep only
2. Note today's log path — but **do NOT write any entry yet**
3. Write the first entry only after the first meaningful action occurs in this session
4. Use the format: `Session start — <what was done>`

> Do not write a log entry just because `/work-log init` was called. Wait for real work to happen.
