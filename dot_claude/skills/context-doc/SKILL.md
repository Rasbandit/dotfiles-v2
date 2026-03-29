---
name: context-doc
description: Save and retrieve context docs so Claude never rediscovers the same system twice. Trigger on "/context-doc", "save this as a context doc", "document how we did X". Also triggers automatically per CLAUDE.md mandate after fixing non-obvious bugs, discovering gotchas, completing integration work, or abandoning failed approaches.
argument-hint: [<system or topic> | list]
---

# Context Doc Skill

Save and retrieve context docs so Claude never rediscovers the same system twice — including dead ends and known errors.

## Triggers
- `/context-doc`
- "save this as a context doc"
- "document how we did X"
- "don't forget how to connect to X"
- "show my context docs" / "what systems are documented"
- After completing any non-trivial discovery (SSH, API auth, CLI quirk, etc.)
- After abandoning a failed approach in favor of another
- After hitting an unexpected error mid-task (update the doc with what failed)

**What counts as non-trivial:** you had to try more than one approach, or it took meaningful effort to figure out. When in doubt, save it.

---

## Mode: SAVE

### Step 1 — Scope
Ask (or infer from context): is this **repo-specific** (this project's server, this API) or **global/reusable** (a CLI tool, a pattern used across projects)?

### Step 2 — Extract
Gather the following from the conversation or ask the user:
- System name (e.g., "Unraid FastRaid", "GitHub CLI", "Stripe API")
- Current status (working, broken, deprecated?)
- Connection method (endpoint, host, port, protocol)
- Auth location and pattern
- Environment (OS, software version, which host)
- Key commands and patterns
- Gotchas (things that caused errors or weren't obvious)
- Failed approaches / dead ends (what was tried that doesn't work)

### Step 3 — Check before creating
- **Repo:** does `docs/context/[system-slug].md` exist in the current repo?
- **Global:** `mcp__engram__search_notes(query="context doc [system]", limit=3)`
- If found: **update** it; if not: **create** it.

### Step 4 — Write

**Repo path:** `docs/context/[system-slug].md`
- Create `docs/context/` directory if it doesn't exist
- Use the template below

**Global path:** Engram note
- Folder: `Context Docs`
- Tags: `context-doc`, `[system-slug]`

### Step 5 — Add soft reference to repo CLAUDE.md
Append under a `## Context Docs` section (create section if missing):
```
If you need info on [System Name], see `docs/context/[system-slug].md`
```
**Do NOT use `@` import syntax.**

### Step 6 — Confirm
Report the file path or Engram note path that was created/updated.

---

## Context Doc File Template

```markdown
# Context Doc: [System Name]

_Last verified: YYYY-MM-DD_

## Status
Working | Broken (as of YYYY-MM-DD — reason) | Deprecated (replaced by X)

## What This Is
One-line description.

## Environment
OS, software versions, which host(s) this applies to (e.g., FastRaid only, Fedora 39+).

## Connection
Endpoint, host, port, protocol.

## Auth
Where credentials live, how auth works, token/key patterns.

## Key Commands / Patterns
Essential commands and patterns to work with this system.

## Failed Approaches / Dead Ends
Things that were tried and don't work. Saves future agents the same wrong turns.

## Gotchas
Things that caused errors or weren't obvious from docs.

## References
Related file paths, URLs, or Engram notes.
```

---

## Mode: CHECK (ambient — run silently before any non-trivial discovery)

1. Identify the system being worked with.
2. Check repo: does `docs/context/[system-slug].md` exist? If yes, read it.
3. Check global: `mcp__engram__search_notes(query="context doc [system]", limit=3)`
4. **If found:** use it; briefly acknowledge — _"Found a context doc for [system] — using that."_
5. **If not found:** proceed with discovery. After discovery completes, **create the context doc immediately** using Mode: SAVE. No permission needed. Do not ask.
6. **If `Last verified` date is >90 days old:** flag — _"Context doc for [system] was last verified on [date] — it may be stale."_
7. **If you hit an unexpected error mid-task:** check the context doc's `## Failed Approaches` and `## Gotchas` sections before debugging. The error may already be documented.

---

## Mode: AUTO (triggered by CLAUDE.md mandatory events — no user invocation needed)

When any of the following events occur, create or update the relevant context doc without asking:

- Fixed a non-obvious bug (document root cause + failed approaches)
- Discovered a gotcha or undocumented behavior
- Completed setup, integration, or connection work
- Abandoned a failed approach in favor of another
- Hit an unexpected error not covered by an existing context doc
- Completed multi-step discovery that took real effort

### Routing
- **In a repo** (`.git` exists): use Mode: SAVE to write to `docs/context/`.
- **Outside a repo** (no `.git`, e.g. working in `~`): use `/engram-save` instead — there's no repo-local docs to write to.
- **Cross-project knowledge** (useful beyond this repo): use `/engram-save` even inside a repo.

### How to execute
**Spawn a background Agent** with a brief summary of what was discovered/fixed and which system it relates to. The agent runs Mode: SAVE (or `/engram-save` per routing above) — checking for existing docs, writing the template, and adding the soft reference to CLAUDE.md. This keeps the main conversation context lean.

**No permission needed. Do not ask "Should I save this as a context doc?" — just do it.**

---

## Mode: LIST

Triggers: "show my context docs", "what systems are documented"

1. **Repo:** list files in `docs/context/` of the current repo.
2. **Global:** `mcp__engram__list_folder(folder="Context Docs")`
3. Present both lists clearly, labeled by scope, including the `Last verified` date and `Status` for each.
