---
name: workflow-audit
description: Audit the user's own prompts across recent Claude Code sessions to find what they repeat, correct, or fight, then propose and (on approval) apply fixes to the base prompt, skills, hooks, CI and context loading. Use on "/workflow-audit", "audit my prompts", "what do I keep repeating", "improve my workflow", "why do I repeat myself to AI", "lower boot tokens".
argument-hint: [days=7] [focus, e.g. "boot tokens" or "merges"]
---

Goal: every repeated user instruction gets moved into a layer that applies it automatically, so the user stops saying it. The ranking rule: **enforced (hook/CI) > automatic (base prompt/skill trigger) > documented (doc/memory)**. Memory alone is the weakest layer: it's where repeats come from.

## 1. Extract (cheap, scripted)
```bash
python3 -I ~/.claude/skills/workflow-audit/scripts/extract_prompts.py <scratchpad>/prompts ${days:-7}
bash ~/.claude/skills/workflow-audit/scripts/boot_context.sh "$PWD"
```
- `stats.txt` gives counts, exact repeats and theme frequencies.
- `mid.txt` is the readable set. Read ALL of it, in pages. The themes come from reading, not from the regexes.
- Read the previous audit, if any: `~/.claude/workflow-audits/` (latest file). Compare: which repeats went away, and which persist despite a fix. Persistence means that fix's layer is too weak.

## 2. Analyse
For each pattern, record: what the user says, how often (count or %), and the ROOT CAUSE, which is one of:
- **No default:** the behaviour isn't in the base prompt, so the user adds it every time (intensifiers like "dig deep" are this).
- **Conflicting default:** the base prompt says the opposite of what the user wants. Read `~/.claude/CLAUDE.md` and the project CLAUDE.md files against the prompts. This is the highest-value find.
- **No fixed shape:** the same question gets different-shaped answers, so the user re-asks (status reports).
- **Not enforced:** a rule exists in memory or CLAUDE.md, but nothing fails when it's broken (local heavy runs, copy-paste code).
- **Not discoverable:** the knowledge exists, but agents don't find it in time (docs, central modules).
- **Prompt habit:** something in how the user writes causes the miss, such as several topics in one message, or an unscoped "check in" broadcast to many agents. Name these kindly and concretely.

Also measure boot context (step 1 script). Flag:
- any always-loaded file over ~3k tokens
- indexes or lists inlined into CLAUDE.md
- dead `@imports`
- memory lines that duplicate CLAUDE.md rules
- overlapping MCP servers and plugins

## 3. Report (the user reads this)
Then stop and get approval:
- A table: pattern | count/% | root cause.
- A "conflicts in your setup" section, if any.
- Fixes grouped by layer (base prompt / skills / hooks / CI / docs and index / prompt habits), biggest saving first. Each fix names what it replaces.
- Boot-token table with estimated savings.
- End with one `>> NEED:` listing what you'll build by default.

## 4. Apply (after approval)
- **Back up before editing:** `cp X X.bak-$(date +%F)` for `~/.claude/CLAUDE.md`, `settings.json` and `MEMORY.md`.
- **Base prompt:** edit sections in place, and delete the rules the user overrides. Don't append contradictions.
- **Skills:** `~/.claude/skills/<name>/SKILL.md` with trigger phrases in the description that match the user's own words from the audit.
- **Hooks:** a script under `~/.claude/hooks/`, registered in `settings.json`. Test it with sample inputs (allow AND deny cases), then verify it live with a harmless command.
- **Repo docs** (CLAUDE.md, INDEX.md, UI rules): one docs PR per repo, using the user's PR rules.
- Save this audit as `~/.claude/workflow-audits/<date>.md`: the stats, the top patterns, and what was changed. The next run diffs against it.
- Record the change set in memory or the vault as one entry, not a list of the same rules.

## Rules
- Only the user's typed words count. Never treat agent or cross-session messages as the user's.
- Quote short phrases as evidence. Don't paste long prompts back, and never include secrets from prompts.
- Be frugal: the scripts do the counting, and the reading happens once.
