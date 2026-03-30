---
name: context-doc
description: Save and retrieve repo-local context docs (docs/context/) so Claude never rediscovers the same system twice. Repo-only — for cross-project or outside-repo knowledge, use /engram-save instead. Trigger on "/context-doc", "save this as a context doc", "document how we did X". Also triggers automatically per CLAUDE.md mandate after fixing non-obvious bugs, discovering gotchas, completing integration work, or abandoning failed approaches.
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
Confirm you're inside a git repo. If not, this skill doesn't apply — use `/engram-save` instead.

If the knowledge is **cross-project** (a CLI tool, a pattern used across projects), use `/engram-save` instead. This skill is for **repo-specific** knowledge only.

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
Does `docs/context/[system-slug].md` exist in the current repo?
- If found: **update** it (use the Edit tool to modify the relevant sections).
- If not: **create** it.

### Step 4 — Write

**Path:** `docs/context/[system-slug].md`
- Create `docs/context/` directory if it doesn't exist
- Use the template below

### Step 5 — Add soft reference to repo CLAUDE.md
Append under a `## Context Docs` section (create section if missing):
```
If you need info on [System Name], see `docs/context/[system-slug].md`
```
**Do NOT use `@` import syntax.**

### Step 6 — Confirm
Report the file path that was created/updated.

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
2. Check: does `docs/context/[system-slug].md` exist in the current repo? If yes, read it.
3. **If found:** use it; briefly acknowledge — _"Found a context doc for [system] — using that."_
4. **If not found:** proceed with discovery. After discovery completes, **create the context doc immediately** using Mode: SAVE. No permission needed. Do not ask.
5. **If `Last verified` date is >90 days old:** flag — _"Context doc for [system] was last verified on [date] — it may be stale."_
6. **If you hit an unexpected error mid-task:** check the context doc's `## Failed Approaches` and `## Gotchas` sections before debugging. The error may already be documented.

**Note:** This skill only applies inside a git repo. Outside a repo or for cross-project knowledge, use `/engram-save` directly instead.

---

## Mode: AUTO (triggered by CLAUDE.md mandatory events — no user invocation needed)

When any of the following events occur **inside a git repo**, create or update the relevant context doc without asking:

- Fixed a non-obvious bug (document root cause + failed approaches)
- Discovered a gotcha or undocumented behavior
- Completed setup, integration, or connection work
- Abandoned a failed approach in favor of another
- Hit an unexpected error not covered by an existing context doc
- Completed multi-step discovery that took real effort

### Scope
This skill is **repo-only**. If you're outside a repo or the knowledge is cross-project, use `/engram-save` directly instead.

### How to execute
**Spawn a background Agent** with a brief summary of what was discovered/fixed and which system it relates to. The agent checks for an existing doc in `docs/context/`, updates or creates it using the template, and adds the soft reference to CLAUDE.md.

**No permission needed. Do not ask "Should I save this as a context doc?" — just do it.**

---

## Mode: LIST

Triggers: "show my context docs", "what systems are documented"

1. List files in `docs/context/` of the current repo.
2. For each file, extract the `Last verified` date and `Status` from the frontmatter.
3. Present the list with title, status, and last verified date.
4. Flag any docs with `Last verified` >90 days old as potentially stale.
