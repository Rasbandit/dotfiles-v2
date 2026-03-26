---
description: Edit or update an existing note in the personal knowledge base (Obsidian vault). Use when user says "update my note on X", "add to my note about X", "change the section on Y in my note", "fix the part where it says Z", "append this to my note", or any time they want to modify an existing note rather than create a new one. Prefer this over engram-save when the user's intent is clearly to modify something already saved.
argument-hint: <what to change and in which note>
---

Edit an existing note in the knowledge base. Request: $ARGUMENTS

## 1. Find the note

`mcp__engram__search_notes(query=<topic>, limit=5)`

If all returned scores are identical, the search has no semantic match — don't repeat the same query. Try one alternative phrasing, then fall back to browsing at most 2 likely folders with `mcp__engram__list_folder`. If still not found, stop and ask the user to clarify the note title or path.

If multiple plausible matches, show top 2–3 titles and confirm with the user before editing.

## 2. Read it (when needed)

Run `mcp__engram__get_note(source_path=<path>)` before any targeted edit or full rewrite. Skip only for plain appends where exact placement doesn't matter.

## 3. Choose operation

| Intent | Tool |
|--------|------|
| Append / add content | `append_to_note(path, text)` — creates the note if it doesn't exist |
| Replace a whole section | `update_section(path, heading, new_content)` |
| Surgical text swap | `patch_note(path, find, replace)` |
| Full rewrite (explicit) | `write_note(path, content)` — only when user explicitly asks to replace everything |

Key constraints:
- `update_section` / `patch_note` require the note to exist — if not found, ask the user to clarify rather than creating
- `update_section` — heading must match exactly (case-sensitive); preserve untouched substructure
- `patch_note` — copy `find` verbatim from the note; even minor whitespace differences cause silent failure
- `write_note` — read the note first so you preserve content the user didn't ask to change
- If creating a new note via `append_to_note`, use `mcp__engram__suggest_folder` to pick the right path

Format all content as clean markdown.

## 4. Confirm

One line: `Updated "[Note Title]" → <operation> [path]`

If not found: `Not found: "[search term]" — checked [what you checked]. Can you clarify the note title or folder?`
