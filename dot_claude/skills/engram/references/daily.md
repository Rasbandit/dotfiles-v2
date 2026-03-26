# Daily Operations

## Intent patterns

- "daily note"
- "add to today"
- "what's on today"
- "today's note"
- "log to today"
- "open today's note"
- "yesterday's note"
- "morning pages"
- "what did I log today"

---

## Operations

### daily-read

Reading today's (or a specific date's) daily note.

**Tier 3 (Full):**

1. Resolve date (see date-resolution below):
   - "today" → current date (YYYY-MM-DD)
   - "yesterday" → current date - 1 day
   - Explicit dates pass through as-is

2. Read the daily note:
   - `mcp__engram__search_notes(query="daily note YYYY-MM-DD", limit=3)` to locate the note
   - If found, use `mcp__engram__get_note(source_path=<path>)` to read it
   - Summarize key content, don't dump raw markdown

3. If no note found for that date:
   - Tell the user clearly: "No daily note found for [date]"
   - Suggest creating one if appropriate

**Tier 2 (CLI):**

1. Resolve date

2. Read the daily note:
   - Today: `obsidian daily:read`
   - Specific date: `obsidian daily:read --date <YYYY-MM-DD>`
   - Summarize key content, don't dump raw markdown

3. If no note found for that date:
   - Tell the user clearly and suggest creating one if appropriate

**Tier 1 (Files):**

1. Resolve date

2. Derive daily note path from common patterns:
   - Check for patterns: `Journal/YYYY-MM-DD.md`, `Daily/YYYY-MM-DD.md`, `Daily Notes/YYYY-MM-DD.md`
   - Use `mcp__filesystem__search_files(path=<vaultPath>, pattern="**/*YYYY-MM-DD.md")` or similar to locate the file
   - If found, read with `mcp__filesystem__read_text_file(path=<full_path>)`
   - Summarize key content

3. If no daily note exists for that date:
   - Tell the user clearly
   - Suggest creating one if appropriate

---

### daily-create

Create today's daily note (from template if available).

**Tier 3 (Full):**

1. Check for existing daily note for today:
   - `mcp__engram__search_notes(query="daily note today", limit=1)`
   - If exists, tell the user and ask if they want to append or open instead

2. Create the note:
   - `mcp__engram__create_note(title="<YYYY-MM-DD>", content="# YYYY-MM-DD\n\n", tags=["daily"])`
   - Engram will auto-place in the appropriate folder
   - Confirm creation with path

**Tier 2 (CLI):**

1. Check for existing daily note for today:
   - `obsidian daily:read` or `obsidian search "daily YYYY-MM-DD"`
   - If exists, tell the user and ask if they want to append or open instead

2. Create the note:
   - `obsidian daily:create`
   - Creates from vault's daily note template if configured
   - Returns the path
   - Confirm creation

**Tier 1 (Files):**

1. Check for existing daily note for today using `mcp__filesystem__search_files`:
   - If exists, tell the user and ask if they want to append or open instead

2. Determine the daily note folder by examining existing daily notes:
   - Use `mcp__filesystem__search_files(path=<vaultPath>, pattern="**/20[0-9][0-9]-*.md")` to find pattern
   - Extract the folder path from the first match
   - If no existing daily notes, use `Journal/` as default, or ask the user

3. Create the file:
   - `mcp__filesystem__create_directory(path=<folder>)` if it doesn't exist
   - `mcp__filesystem__write_file(path=<folder>/YYYY-MM-DD.md, content="# YYYY-MM-DD\n\n")`
   - Confirm creation with path

---

### daily-append

Add content to today's daily note.

**Tier 3 (Full):**

1. Resolve date (default to today if not specified)

2. Check if daily note exists:
   - `mcp__engram__search_notes(query="daily note YYYY-MM-DD", limit=1)`

3. If it exists:
   - Read it: `mcp__engram__get_note(source_path=<path>)`
   - Append the new content as a new paragraph or section
   - Update it using search/update pattern (treat as update-note operation from `references/update.md`)

4. If it doesn't exist:
   - Create it first (use `daily-create` steps)
   - Then append the content

**Tier 2 (CLI):**

1. Resolve date (default to today)

2. Append to the note:
   - `obsidian daily:append --text "<content>"` (or similar CLI syntax)
   - If the note doesn't exist, create it first with `obsidian daily:create`

**Tier 1 (Files):**

1. Resolve date (default to today)

2. Locate the daily note file using same pattern as `daily-read`

3. If it exists:
   - Read it with `mcp__filesystem__read_text_file(path=<path>)`
   - Append the new content as a new paragraph or section
   - Write it back with `mcp__filesystem__write_file(path=<path>, content=<updated markdown>)`

4. If it doesn't exist:
   - Create it first using `daily-create` Tier 1 steps
   - Then append the content

---

### date-resolution

Handle date references in user messages. Always resolve to YYYY-MM-DD format for all operations.

**For all tiers:**

| User input | Resolution |
|---|---|
| "today" | Current date (use system date) |
| "yesterday" | Current date - 1 day |
| "tomorrow" | Current date + 1 day |
| "last Monday" / "last Tuesday" / etc. | Most recent occurrence of that day |
| "March 15" / "15 March" | Current year + specified month/day → YYYY-MM-DD |
| Explicit YYYY-MM-DD | Pass through as-is |
| Relative offsets ("3 days ago") | Calculate and convert to YYYY-MM-DD |

**Implementation:**
- Use standard date parsing (e.g., JavaScript Date, Python datetime, or shell date utility)
- Always output YYYY-MM-DD format
- If ambiguous (e.g., month/day order), ask the user to clarify

---

## Examples

1. **"what's on my daily note?"**
   - Intent: daily-read for today
   - Resolve date: today
   - Read today's daily note, summarize content

2. **"add 'finished the auth refactor' to today's note"**
   - Intent: daily-append
   - Resolve date: today
   - Append text to today's daily note (create if missing)

3. **"show me yesterday's daily note"**
   - Intent: daily-read
   - Resolve date: yesterday (current date - 1 day)
   - Read and summarize

4. **"create today's daily note"**
   - Intent: daily-create
   - Resolve date: today
   - Create the note with date heading, confirm path

5. **"log to March 15's daily note: met with the design team"**
   - Intent: daily-append
   - Resolve date: March 15 → YYYY-03-15
   - Locate/create note and append the log entry

6. **"what did I write on my daily note 5 days ago?"**
   - Intent: daily-read
   - Resolve date: current date - 5 days → YYYY-MM-DD
   - Read and summarize
