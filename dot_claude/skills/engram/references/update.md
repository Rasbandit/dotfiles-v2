# Update Operations

## Intent patterns

- "append to"
- "update my note"
- "add to my note"
- "change the section"
- "fix the part where"
- "edit my note"
- "insert into"
- "add a section to"

---

## Operations

All update operations start with finding the note (search-then-act pattern).

### find-note (shared first step)

**Tier 3 (Full):** `mcp__engram__search_notes(query=<topic>, limit=5)`
**Tier 2 (CLI):** `obsidian search "<topic>"`
**Tier 1 (Files):** `grep -ril "<topic>" <vaultPath>/`

If all returned scores are identical (Tier 3) or no clear match: try one alternative phrasing, then browse likely folders with `mcp__engram__list_folder` (Tier 3) or `obsidian folders` (Tier 2) or `ls` (Tier 1). If still not found, ask the user to clarify.

If multiple plausible matches: show top 2–3 titles and confirm before editing.

---

### append

Add content to the end of a note.

**Tier 3 (Full):**

`mcp__engram__append_to_note(path=<path>, text=<content>)`

Note: `append_to_note` creates the note if it doesn't exist. If creating via append, use `mcp__engram__suggest_folder` to pick the right path first.

**Tier 2 (CLI):**

`obsidian append "<title>" --text "<content>"`

**Tier 1 (Files):**

Read the file with `mcp__filesystem__read_text_file`, append the content, write back with `mcp__filesystem__write_file`.

---

### update-section

Replace content under a specific heading.

**Tier 3 (Full):**

1. Read first: `mcp__engram__get_note(source_path=<path>)`
2. Locate the exact heading string (case-sensitive).
3. `mcp__engram__update_section(path=<path>, heading=<heading>, new_content=<content>)`

**Tier 2 (CLI):**

1. `obsidian read "<title>"` to inspect structure.
2. `obsidian edit "<title>" --heading "<heading>" --content "<content>"`

**Tier 1 (Files):**

1. Read file with `mcp__filesystem__read_text_file`.
2. Locate the heading line, replace section content up to the next same-level heading.
3. Write back with `mcp__filesystem__write_file`.

Key constraints:
- Heading must match EXACTLY (case-sensitive).
- Preserve untouched sub-headings and their content.
- Always read before editing so you understand the note's structure.

---

### patch

Surgical text swap — find and replace specific text within a note.

**Tier 3 (Full):**

1. Read first: `mcp__engram__get_note(source_path=<path>)`
2. Copy the target text VERBATIM from the note content.
3. `mcp__engram__patch_note(path=<path>, find=<old_text>, replace=<new_text>)`

**Tier 2 (CLI) / Tier 1 (Files):**

1. Read the file.
2. Find the exact text and replace it in content.
3. Write back.

Key constraint: The `find` value must be copied VERBATIM from the note — even minor whitespace differences cause silent failure.

---

### rewrite

Full note replacement — ONLY when user explicitly asks to replace everything.

**Tier 3 (Full):**

1. Read first: `mcp__engram__get_note(source_path=<path>)` — preserve content the user didn't mention.
2. `mcp__engram__write_note(path=<path>, content=<new_content>)`

**Tier 2 (CLI):**

1. `obsidian read "<title>"` to review existing content.
2. `obsidian write "<title>" --content "<content>"`

**Tier 1 (Files):**

1. Read the file with `mcp__filesystem__read_text_file`.
2. Rewrite content.
3. Write back with `mcp__filesystem__write_file`.

Key constraint: ALWAYS read before rewriting. Preserve content the user didn't ask to change. Only use rewrite when user explicitly says "replace everything" or "rewrite the whole note".

---

## Confirmation

After any update:
```
Updated "[Note Title]" → <operation> [path]
```

If not found:
```
Not found: "[search term]" — checked [what you checked]. Can you clarify the note title or folder?
```

---

## Examples

1. **"add to my Unraid note: vDisk bus should be VirtIO for Windows VMs"**
   - Find the Unraid note via search.
   - Append the text to the end of the note.

2. **"update the installation section in my Docker note"**
   - Find the Docker note.
   - Read it to confirm the exact heading text.
   - Use `update-section` with the matched heading.

3. **"fix the typo in my health note where it says 'magnesuim'"**
   - Find the health note.
   - Read to locate the exact string.
   - Use `patch` with the verbatim misspelling as `find` and the correction as `replace`.

4. **"add a Resources section to my Kubernetes note"**
   - Find the Kubernetes note.
   - Read to confirm there's no existing Resources heading.
   - Use `update-section` to insert the new heading and content, or `append` if adding at the end.

5. **"rewrite my morning routine note with this new version"**
   - Find the morning routine note.
   - Read to understand current content.
   - Confirm user wants full replacement, then use `rewrite`.
