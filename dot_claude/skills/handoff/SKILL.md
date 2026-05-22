---
name: handoff
description: Compact the current conversation into a handoff doc at /tmp/handoff-<date>-<slug>.md and print a paste-ready prompt for a fresh session to continue the work. Use when context is filling up but work remains. Trigger on "/handoff", "write a handoff", "hand this off", "prep for new session", "pick this up later".
argument-hint: [<what the next session will focus on>]
---

You are writing a brief for another AI who will pick up this work in a fresh session with zero memory of the current conversation. Their context window is precious. Include only what they can't reconstruct from the codebase, the user's CLAUDE.md, or referenced artifacts (PRs, plans, context-docs, issues, commits, diffs). Reference those by path or URL — never duplicate them.

`$ARGUMENTS`, if provided, describes what the next session will focus on. Use it to anchor the doc and the paste-ready hook.

## Step 1 — Decide focus + slug

- If `$ARGUMENTS` is non-empty, treat it as the focus statement for the next session.
- Otherwise infer focus from the recent conversation — the unfinished thread, the open question, the next obvious move.
- Derive a kebab-case slug (2–4 words, task-flavored). Examples: `pricing-defenses`, `ci-flake-debug`, `handoff-skill-design`.
- Compute the output path: `/tmp/handoff-$(date +%Y-%m-%d)-<slug>.md`

## Step 2 — Gather context (dynamically — you decide what's worth pulling)

You are the judge of what context the next AI will need. The following tools are available — use the ones that help, skip the ones that don't. A two-hour bug hunt needs different evidence than a half-finished feature implementation. Pull what the next AI couldn't reconstruct on their own.

Available context sources:

- **`git status` + `git diff --stat`** — in-flight changes the next AI must know about
- **`git log <base>..HEAD --oneline`** — local commits on this branch since divergence from main
- **`git branch --show-current`** — current branch name
- **`gh pr view <n>` / `gh issue view <n>`** — resolve titles + status for any PR/issue numbers referenced in the conversation
- **Today's work-log entries** — `1. Alignment/4. Work Log/YYYY-MM/YYYY-MM-DD.md` via `mcp__engram__read_note` for a timeline of actions taken this session
- **`docs/context/` index** — repo-local context docs to reference by path (don't duplicate their content)
- **Recent file edits in this session** — already in your context; list them by path with one-line "why"
- **Memory files** — `MEMORY.md` index entries relevant to the focus, referenced by `[[name]]`

**Anti-patterns — do not:**
- Paste full PR diffs, file contents, or context-doc bodies. Link them.
- Include things the next AI will see in CLAUDE.md anyway.
- Re-summarize plans that already live in a plan file — point to the file.
- Mechanically dump everything available. Curate.

## Step 3 — Fill this template

Sections may be omitted when not applicable (e.g. no blockers → drop the section, don't write "None"). Your call.

```markdown
# Handoff: <focus statement>

**Date:** YYYY-MM-DD
**From session:** <one-line summary of where this session started>
**For next session:** <one-line summary of the focus — what success looks like>

## Task & Why

<what is being worked on and the motivation — 2–4 sentences. The "why" matters: it lets the next AI judge edge cases.>

## Current State

<where things stand right now: branch name, what's committed locally, what's pushed, what's deployed, what's pending review, what's blocked>

## Decisions Made

<decisions the user locked in during this session that the next AI must respect — bullet list. Include the *why* for each so the next AI can judge whether the decision still applies to a new situation.>

## Files Touched

<files edited/created with a one-line "why" each. Path, not content.>

## Next Steps

<ordered list of what to do next. Specific enough to act on without re-deriving — name files, name commands, name acceptance criteria.>

## Blockers / Open Questions

<things waiting on the user, unresolved design questions, external dependencies. Omit if none.>

## Tried & Rejected

<approaches already attempted that didn't work — so the next AI doesn't redo them. Each entry: what was tried, why it failed. Omit if none.>

## References

<everything the next AI should read for full context: PR URLs, issue numbers, plan file paths, context-doc paths, memory entries by [[name]], engram note paths, external docs. One line each.>
```

## Step 4 — Redact secrets

Before writing, scan the drafted doc for sensitive content. Replace with `[REDACTED:<type>]`:

- API keys, access tokens, refresh tokens, session tokens
- Passwords, passphrases, master keys, encryption keys, age keys
- JWTs (any string matching `eyJ...`)
- AWS access keys (`AKIA...`, `ASIA...`)
- Private SSH keys, PGP private keys
- Database connection strings with embedded credentials
- Webhook secrets, signing keys
- PII beyond what's already in the user's CLAUDE.md (the user's own name + email are fine)

If unsure whether something is sensitive, redact it. The cost of redaction is near zero; the cost of leaking is high.

## Step 5 — Write the file

Use the Write tool. Path from Step 1: `/tmp/handoff-YYYY-MM-DD-<slug>.md`. Overwrite if it exists — `/tmp` is ephemeral by design.

## Step 6 — Emit ONLY the paste-ready output block

After the file is written, your entire response is this block — no preamble, no "I've created the handoff", no closing remarks. The user will copy the two inner lines verbatim into a fresh session.

```
── COPY BELOW ──
Read /tmp/handoff-YYYY-MM-DD-<slug>.md and continue <one-line hook derived from focus>.
── END ──
```

The hook is one short clause that names the immediate next action (e.g. "the §G opt-outs work, device-auth pair next", "debugging the CI flake on e2e-browser job", "wiring the Paddle webhook signature check"). It exists so the user knows at a glance which handoff they're pasting.

## Examples

**Input:** `/handoff finish the §G opt-outs`

**Output (after writing `/tmp/handoff-2026-05-22-g-opt-outs.md`):**
```
── COPY BELOW ──
Read /tmp/handoff-2026-05-22-g-opt-outs.md and continue the §G opt-outs work — device-auth pair next.
── END ──
```

**Input:** `/handoff` (no args, mid-bug-hunt)

**Output (after writing `/tmp/handoff-2026-05-22-ci-tailwind-flake.md`):**
```
── COPY BELOW ──
Read /tmp/handoff-2026-05-22-ci-tailwind-flake.md and continue debugging the e2e-browser tailwind :eacces flake.
── END ──
```
