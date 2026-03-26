# Read Operations

## Intent patterns

- "read my note on"
- "show me my note"
- "open note"
- "pull up"
- "what does my note say about"
- "show me what I wrote about"
- "get my note on"
- "display my notes about"

---

## Operations

### read-note

Reading a specific note by name or topic.

**Tier 3 (Full):**

1. **If path is known** (user provided full path or breadcrumbs):
   - `mcp__engram__get_note(source_path=<path>)`
   - Summarize or quote relevant sections — do not dump raw content.

2. **If path is unknown** (user provided only a topic or partial name):
   - Run `mcp__engram__search_notes(query=<topic>, limit=5)` to find candidates.
   - If multiple matches: show top 2–3 titles and ask which one to read.
   - Once confirmed, run `mcp__engram__get_note(source_path=<path>)`.
   - Summarize relevant sections.

**Tier 2 (CLI):**

1. **If path is known:**
   - `obsidian read "<note title or path>"`
   - Summarize relevant sections.

2. **If path is unknown:**
   - `obsidian search "<topic>"` to find candidates.
   - If multiple matches: show top 2–3 titles and ask which one to read.
   - Once confirmed, run `obsidian read "<note title>"`.
   - Summarize relevant sections.

**Tier 1 (Files):**

1. **If path is known:**
   - Use `mcp__filesystem__read_text_file(path=<full_path>)` to read directly.
   - Summarize relevant sections.

2. **If path is unknown:**
   - `mcp__filesystem__search_files(path=<vaultPath>, pattern="**/*.md")` to find candidates by name.
   - If name search doesn't work: `grep -ril "<topic>" <vaultPath>/` to search file contents.
   - For the top 3–5 matches, read the first ~20 lines of each to extract an excerpt.
   - Present candidates with excerpts and ask which note to read in full.
   - Once confirmed, read the full file and summarize relevant sections.

**For all tiers:**
- Always summarize or excerpt — never dump raw markdown unless explicitly asked.
- If the user asked about a topic (not a specific note), search first, confirm which note, then read.
- If multiple matches and user didn't specify, show top 2–3 candidates with a brief excerpt from each.

---

### read-excerpt

Reading a specific section from a note.

**All tiers:**

1. Determine which note to read:
   - **If path is known:** skip to step 2.
   - **If path is unknown:** use the same search flow as `read-note` (Tier 3: semantic search; Tier 2: CLI search; Tier 1: grep + filesystem).

2. Read the full note using the appropriate method for your tier (see `read-note` above).

3. Extract and present only the section matching the user's request:
   - If the user mentioned a heading (e.g., "Setup", "Configuration", "Examples"), find and extract that section.
   - If the user asked for a topic within the note, find the most relevant section containing that content.
   - Do not show the entire note — only the targeted section and surrounding context (1–2 lines before/after if helpful).

4. Example response:
   ```
   From your note on Docker networking:

   ## Setup
   [section content]
   ```

---

## Examples

1. **"show me my note on Docker networking"**
   - Tier 3: Search semantically for "Docker networking", confirm the note, read with `mcp__engram__get_note`, present key content.
   - Tier 2: CLI search for "Docker networking", confirm, read with `obsidian read`, present key content.
   - Tier 1: Grep for "Docker networking", read top match with filesystem, present key content.

2. **"read the setup section from my Fedora note"**
   - Find the Fedora note (search if path unknown).
   - Read the full note.
   - Extract the "Setup" heading section and present only that.

3. **"what does my note about supplements say?"**
   - Search for "supplements", confirm the best match.
   - Read the note with the appropriate tier method.
   - Summarize key points without showing raw markdown.

4. **"pull up the troubleshooting part from my Kubernetes note"**
   - Find the Kubernetes note.
   - Read full.
   - Extract the "Troubleshooting" section and present it.

5. **"open my note on morning routine"**
   - Tier 3: `mcp__engram__search_notes(query="morning routine", limit=3)`, confirm best match, read.
   - Tier 2: `obsidian search "morning routine"`, confirm, read.
   - Tier 1: Grep, confirm, read.

---

## No-results handling

If a search returns no results or the note isn't found:

1. Auto-retry once with a rephrased or broader query (try synonyms, remove qualifiers).
2. If still nothing: tell the user clearly, then suggest 2–3 related terms they could try.
3. Do not just say "nothing found" — always give an actionable next step.

Example:
```
No note found for "Docker networking". I also tried "container networking" — still nothing.
You could try: "Docker", "networking", or "infrastructure".
```
