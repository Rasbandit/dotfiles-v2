---
name: engram-save
description: Save a NEW note to the user's Obsidian vault knowledge base. Trigger any time the user wants to capture and preserve something for the first time — a fix they just figured out, an architecture decision, setup steps, a useful command, a protocol, or anything they say they "don't want to forget" or want "future me" to know. Key phrases: "save this", "remember this", "add to vault", "engram this", "save as engram", "keep a note about", "document this". Trigger even without explicit save language when the intent to preserve new knowledge is clear. Do NOT trigger for: finding or recalling existing notes (→ engram-search), modifying or appending to an existing note (→ engram-update), or browsing vault contents (→ engram-browse).
argument-hint: <content to save>
---

Save a note to the user's knowledge base with smart deduplication and semantic auto-placement.

Content to save: $ARGUMENTS

## Steps

### 1. Understand the content
Distill from the content:
- A short, specific **title** (5–8 words, title case, no filler like "Note about...")
- A one-sentence **summary** (used for search and folder matching)
- 2–4 **tags** (lowercase, single words or short hyphenated phrases)

### 2. Check for duplicates
Search for existing notes on the same topic:
```
mcp__engram__search_notes(query=<your summary>, limit=3)
```
Look at the top result. If it's clearly the same topic (not just the same domain), ask inline — keep it to one line:
> `Found: "[existing title]" — append to it or create a new note?`

- **Append** → use `mcp__engram__append_to_note(path=<existing path>, text=<new content>)` then skip to step 5
- **New** → continue to step 3
- **Skip check** if the user explicitly said "create a new note"

If results are adjacent but distinct (same domain, different topic), proceed to step 3 without asking.

### 3. Format the note
```markdown
---
tags: [tag1, tag2]
date: YYYY-MM-DD
---

# Title

<content, faithfully preserved and formatted in markdown>
```

Use today's date. Keep the content faithful — don't summarize or trim unless the input is clearly raw/noisy.

### 4. Save with auto-placement
Do NOT pass `suggested_folder` — let the vault's semantic index place it automatically.
```
mcp__engram__create_note(title=<title>, content=<formatted markdown>)
```
The response will be: `Note created: <full/path/to/note.md> (N chunks indexed)`

### 5. Confirm
Extract the path from the response and tell the user in one line:
> `Saved "[Title]" → <folder path> [tags: tag1, tag2]`
