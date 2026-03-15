---
name: lifeos-onboard
description: Onboard a project into the Life OS tagging system. Use when a project's CLAUDE.md has no `## Life OS` block, when the user says "onboard this project", "add Life OS tags", "set up tagging", or when work log entries can't find tag slugs for the current project. Also triggers proactively when Claude notices a missing Life OS block during normal work.
argument-hint: [project name or path]
---

Onboard a project into Life OS so work log entries get correct `#project/`, `#goal/`, and `#value/` tags.

Project: $ARGUMENTS

## Steps

### 1. Read the reference doc
Read `~/.claude/lifeos-reference.md` for the current goal inventory, templates, and hierarchy.

### 2. Check current state
Read the project's `CLAUDE.md` (current working directory or provided path).
- If a `## Life OS` block already exists, tell the user and stop.
- If not, continue.

### 3. Research existing goals
Use Engram MCP to read all active goal files (folder-per-goal structure):
```
mcp__engram__list_folder(path="1. Alignment/1. Goals/1. Value/1. Active")
mcp__engram__list_folder(path="1. Alignment/1. Goals/2. Outcome/1. Active")
```
Then read each goal file at `<slug>/<slug>.md` to understand slugs, emojis, values, and project associations.

### 4. Suggest a match
Based on the project's purpose (from its CLAUDE.md, README, or repo contents):
- Suggest the best-fit **goal slug** and **value slug**
- If multiple goals could fit, list them ranked with a one-line rationale each
- If no goal fits, say so and offer to create one

Present as a short list — ask the user to pick:
> **Suggested:** `goal: sell-engram` / `value: self-reliance` — this project is part of the Engram product
> **Alt:** `goal: gobigger` / `value: self-reliance` — if this is GoBigger related
> **New goal?** — describe what it would be and I'll create it

### 5. Create new goal (if needed)
If the user wants a new goal:
- Ask: value goal or outcome goal?
- Ask: which parent value? (for outcome goals)
- Ask: priority?
- Use the template from `~/.claude/lifeos-reference.md`
- Include `emoji:` in the frontmatter
- Save via Engram MCP (goal gets its own folder):
```
mcp__engram__create_note(title=<goal name>, content=<filled template>, suggested_folder="1. Alignment/1. Goals/1. Value/1. Active/<slug>")
```
- Also create a project file if the repo maps to this goal:
```
mcp__engram__create_note(title=<project-slug>, content=<project template>, suggested_folder="1. Alignment/1. Goals/.../Active/<goal-slug>/projects")
```

### 6. Add the Life OS block
Append to the project's `CLAUDE.md`:
```markdown

## Life OS
project: <repo-slug>
goal: <goal-slug>
value: <value-slug>
```

Use the Edit tool to add it. Place it before any `## External References` section if one exists, otherwise at the end.

### 7. Confirm
One-line summary:
> Life OS: `#project/<slug> #goal/<slug> #value/<slug>` — added to CLAUDE.md
