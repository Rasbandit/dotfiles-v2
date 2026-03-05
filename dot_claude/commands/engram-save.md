Save a note or piece of information to the user's Obsidian vault for later sorting.

Content to save: $ARGUMENTS

Steps:
1. Read `_AI Instructions.md` at the vault root for any saving conventions
2. Derive a short, descriptive filename from the content (kebab-case, no spaces, .md extension)
3. Save the note to `scratch/<filename>.md` using `mcp__engram__create_note` with `file_text`
4. Format the note with a `# Title` heading and today's date (`YYYY-MM-DD`) at the top
5. Confirm the saved path to the user
