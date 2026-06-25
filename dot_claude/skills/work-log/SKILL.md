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
2. Record the resolved vault ID (a UUID string) and the base folder. The note path is `<worklog_path>/YYYY-MM/YYYY-MM-DD.md` using the **work-day date** (defined below — *not* the raw calendar date).

**If the fields are absent (or there is no CLAUDE.md at all):**

Do NOT guess a vault. Help the user choose, then persist:

1. `mcp__engram__list_vaults` — show the available vaults.
2. For the likely candidate vault(s), call `mcp__engram__set_vault(vault_id="<id>")` then `mcp__engram__list_folders` to show existing work-log folders, then reset with `mcp__engram__set_vault()`.
3. Ask the user which vault + base folder to use.
4. **Persist** the answer: use the Edit tool to add `worklog_vault:` and `worklog_path:` to the project's `## Life OS` block so this is a one-time question. If there is no CLAUDE.md to edit, proceed and append `(worklog destination not persisted — no CLAUDE.md)` to the entry description.

Never read-then-write the log file.

**Work-day date — 06:00 rollover.** Todd routinely works past midnight, so the log "day" runs **06:00 → 06:00**, not midnight → midnight. A session that starts at night and runs to 2am stays in ONE file. Derive the log date by shifting the clock back 6 hours:

```
date -d '6 hours ago' +%Y-%m-%d     # → the YYYY-MM-DD for the note filename + header
date -d '6 hours ago' +%Y-%m        # → the YYYY-MM month folder
```

Anything logged **00:00–05:59 files under the previous calendar day**; 06:00 onward is the new day. Use this work-day date everywhere a path or header needs a date — never the raw `date +%F`. (The clock times inside the `[HH:MM-HH:MM]` stamp are still real wall-clock from `date +%H:%M` — only the file/header date rolls.)

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

**Multi-repo workspace — tag by what the work TOUCHED, not by CWD.** Some projects are a workspace root that contains sub-repos (e.g. `engram-workspace` with `backend/` and `plugin/`). Most work happens *from* the workspace root but targets a sub-repo. Do **not** default to the workspace's own `project:` slug just because that's the current directory. Decide the `#project/` tag from the files the work actually changed:

- Work touched files under a sub-repo dir → use **that sub-repo's** `project:` slug (read its own CLAUDE.md/AGENTS.md `## Life OS` block for the slug).
- Work touched only workspace-level files (root docs, Makefile, the root CLAUDE.md) → use the workspace's own slug.
- The workspace root CLAUDE.md may list an explicit sub-repo → tag map — follow it if present.

The destination vault/folder stays the workspace's `worklog_vault`/`worklog_path` (one shared log); only the `#project/` tag changes per sub-repo.

---

## Step 2 — Get the time

Run `date +%H:%M` to get the current (end) time. This is the real wall-clock for the `[HH:MM-HH:MM]` stamp — independent of the work-day date, which still follows the 06:00 rollover from Step 0 (a 02:00 entry stamps `[02:00-…]` but files under the previous day).

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
   - Prefix the text with `# YYYY-MM-DD\n\n` (the **work-day date**) **only** if this is the very first entry of the work-day.

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

**Description rules — keep it to ONE compact line:**
- **Hard cap ~240 chars (~35 words). One sentence.** If it won't fit, you're logging too much — trim or split into separate entries.
- **Lead with the outcome + the artifact.** What changed and where: file, function, service, config, decision, PR/issue #.
- **Cut the play-by-play.** No "then I… then I…" chains, no diagnostic narrative, no listing every file touched or every CI step, no parenthetical asides. Reference `PR #123` instead of retelling what's in it.
- Past tense, concrete verb: "fixed", "added", "removed", "decided", "merged", "root-caused".
- Skip filler: "worked on", "made changes to", "did some", "updated things".
- One entry = one completed unit of work, not a whole session crammed together.

**Good entries (compact):**
```
[14:00-14:30] #project/gobigger-doterra #goal/gobigger #value/self-reliance Migrated user-service.ts Firestore→Drizzle/Postgres; session auth now on Supabase
[09:15-09:45] #project/open-claw-manager #goal/self-hosting #value/self-reliance Root-caused Navigator cron not firing → missing CLAUDE.md Life OS block; added it
[20:00-20:20] #project/audiobook-tools #goal/self-hosting #value/self-reliance Decided to decouple audiobook-tools from ops-dispatcher — kills a single point of failure
```

**Bad entries (do not write these):**
```
# too vague:
[14:00-14:30] #project/gobigger-doterra #goal/gobigger #value/self-reliance Worked on the database migration
[09:15-09:45] #project/open-claw-manager #goal/self-hosting #value/self-reliance Fixed bug

# too verbose — a whole session in one entry (trim to the outcome + PR #):
[16:30-18:05] #project/engram Built PR #741 — TDD'd Helpers.scrub_utf8/2 telemetry + PromEx counter + :data log category + #738 regression test + #739 backfill task, ran the full format/credo/dialyzer/test gauntlet, bumped 0.5.529, pushed, opened PR, remaining is the Grafana alert which depends on the metric reaching prod via a release tag...
# →
[16:30-18:05] #project/engram #goal/income #value/financial-freedom Shipped PR #741 — UTF-8 scrub telemetry + PromEx counter + #739 backfill task; full gauntlet green, v0.5.529. Follow-up: Grafana alert pending prod metric
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
2. Resolve the destination vault + base folder (Step 0) and note the **work-day** log path (apply the 06:00 rollover) — but **do NOT write any entry yet**. If the project has no `worklog_vault`/`worklog_path`, defer the choose-and-persist flow until the first real entry (do not prompt at init).
3. Write the first entry only after the first meaningful action occurs in this session
4. Use the format: `Session start — <what was done>`

> Do not write a log entry just because `/work-log init` was called. Wait for real work to happen.
