# Create Operations

## Intent patterns

- "save this"
- "create a note"
- "remember this"
- "engram this"
- "document this"
- "write this down"
- "note this"
- "keep a record of"

---

## Operations

### create-note

Creating a new note from user-provided content.

**Step 1: Distill content**

From the user's content, extract:
- A short, specific **title** (5–8 words, title case, no filler like "Note about...")
- A one-sentence **summary** (used for search and folder matching)
- 2–4 **tags** (lowercase, single words or short hyphenated phrases)

---

**Step 2: Dedup check**

Search for existing notes on the same topic:

**Tier 3 (Full):** `mcp__engram__search_notes(query=<summary>, limit=3)`
**Tier 2 (CLI):** `obsidian search "<summary>"`
**Tier 1 (Files):** `grep -ril "<key terms>" <vaultPath>/`

If the top result is clearly the same topic (not just the same domain), ask inline:
> Found: "[existing title]" — append to it or create a new note?

- **Append** → hand off to `references/update.md`'s append operation
- **New** → continue to Step 3
- **Skip check** if user explicitly said "create a new note"

If results are adjacent but distinct (same domain, different topic), proceed without asking.

---

**Step 3: Format the note**

```markdown
---
tags: [tag1, tag2]
date: YYYY-MM-DD
---

# Title

<content, faithfully preserved and formatted in markdown>
```

Use today's date. Keep content faithful — don't summarize or trim unless the input is clearly raw/noisy.

---

**Step 4: Place and save**

**Tier 3 (Full):**
- Do NOT pass `suggested_folder` — let Engram's semantic index place it automatically.
- `mcp__engram__create_note(title=<title>, content=<formatted markdown>)`
- Response includes the path where it was placed.

**Tier 2 (CLI):**
- Resolve placement: check topic scopes (consult `references/scoping.md`) for a matching folder.
- If scope found: use that folder.
- If no scope: ask the user which folder, or suggest based on existing folder names.
- `obsidian create "<title>" --folder "<folder>" --tags "<tags>" --content "<content>"`

**Tier 1 (Files):**
- Same placement logic as Tier 2 (scoping or ask user).
- Ensure the target folder exists: `mcp__filesystem__create_directory(path=<folder>)` if needed.
- Write the file: `mcp__filesystem__write_file(path=<vaultPath>/<folder>/<title>.md, content=<formatted markdown>)`

---

**Step 5: Confirm**

One line:
```
Saved "[Title]" → <folder path> [tags: tag1, tag2]
```

---

## Examples

1. **"save this: I figured out NVIDIA driver fix on Fedora — run akmods --force then dracut --force before reboot"**
   Distill title ("NVIDIA Driver Fix on Fedora"), check for existing NVIDIA or driver notes, create with auto-placement (Tier 3) or scoped folder (Tier 2/1).

2. **"remember this protocol for deploying to Unraid..."**
   Distill title and tags from content, dedup check, place in infrastructure/homelab scope or ask user.

3. **"engram this: my morning routine involves..."**
   Distill, check for existing routine notes, create. If a morning routine note already exists, offer to append instead.

---

## No-match handling

If dedup check returns no results:
- Skip the dedup question entirely and proceed to Step 3.
- Do not tell the user "no duplicates found" — just continue silently.
