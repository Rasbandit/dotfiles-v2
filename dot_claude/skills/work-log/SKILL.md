---
name: work-log
description: Write one or more entries to the daily work log. Use at session start to initialize today's file, and after every meaningful action to append an entry. Trigger on "/work-log", "log this", "log my work", or "add to work log". Also triggers automatically at session start per CLAUDE.md mandate.
argument-hint: [init | <description of work done>]
---

Write to the daily work log. If `$ARGUMENTS` is `init` or empty, run the session-start procedure. Otherwise append a single entry describing the work in `$ARGUMENTS`.

## Step 0 — Resolve the destination (vault + folder)

The destination vault and base folder come from the project's `## Life OS` block — the same block that supplies the tags. Read the current project's CLAUDE.md (CWD or nearest parent dir) and extract:

```markdown
## Life OS
worklog_vault: <vault name>          # e.g. "Engram" or "My Vault"
worklog_path: <base folder>          # e.g. "1. Alignment/4. Work Log"
```

**If both fields are present:**

1. Call `mcp__engram__list_vaults`. Match `worklog_vault` to a vault by name, **case-insensitive, exact**.
   - No match, or more than one match → **STOP**. Tell the user the name is unresolvable and list the available vault names. Do NOT write anything.
2. Record the resolved vault ID (a UUID string) and the base folder. The note path is `<worklog_path>/YYYY-MM/YYYY-MM-DD.md` using today's date.

**If the fields are absent (or there is no CLAUDE.md at all):**

Do NOT guess a vault. Help the user choose, then persist:

1. `mcp__engram__list_vaults` — show the available vaults.
2. For the likely candidate vault(s), call `mcp__engram__set_vault(vault_id="<id>")` then `mcp__engram__list_folders` to show existing work-log folders, then reset with `mcp__engram__set_vault()`.
3. Ask the user which vault + base folder to use.
4. **Persist** the answer: use the Edit tool to add `worklog_vault:` and `worklog_path:` to the project's `## Life OS` block so this is a one-time question. If there is no CLAUDE.md to edit, proceed and append `(worklog destination not persisted — no CLAUDE.md)` to the entry description.

Never read-then-write the log file. Use today's date.

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

## Step 3 — Write the entry

**Use the Engram MCP only.** Do NOT install or invoke any local Obsidian CLI/app — they have crash-looped and OOM'd this machine. The Engram MCP is a remote HTTP service.

1. Switch to the destination vault resolved in Step 0:

   ```
   mcp__engram__set_vault(vault_id="<resolved UUID string>")
   ```

   > GOTCHA: the tool schema declares `vault_id` as an **integer**, but real vault IDs are **UUID strings**. Pass the UUID as a quoted string anyway — the server expects it. (Skip this call only if the destination is already the default vault AND you have not switched away from it this session.)

2. Append the entry:

   ```
   mcp__engram__append_to_note(path="<worklog_path>/YYYY-MM/YYYY-MM-DD.md", text="<entry>")
   ```

   - Creates the file if missing. Use `\n` for newlines.
   - Prefix the text with `# YYYY-MM-DD\n\n` **only** if this is the very first entry of the day.

3. Reset the vault context so the switch does not leak into later MCP calls this session:

   ```
   mcp__engram__set_vault()
   ```

   (no `vault_id` → back to default).

**If the Engram MCP is unavailable or errors:** surface the error to the user. Do NOT silently write to any local path — there is no local vault on this machine.

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
2. Resolve the destination vault + base folder (Step 0) and note today's log path — but **do NOT write any entry yet**. If the project has no `worklog_vault`/`worklog_path`, defer the choose-and-persist flow until the first real entry (do not prompt at init).
3. Write the first entry only after the first meaningful action occurs in this session
4. Use the format: `Session start — <what was done>`

> Do not write a log entry just because `/work-log init` was called. Wait for real work to happen.
