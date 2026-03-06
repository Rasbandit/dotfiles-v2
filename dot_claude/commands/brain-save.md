Save a note or piece of information to the user's Obsidian brain vault for later sorting.

Content to save: $ARGUMENTS

Steps:
1. Read `_AI Instructions.md` at the vault root (`/home/rasbandit/Documents/Obsidian/Personal/_AI Instructions.md`) for any saving conventions
2. Derive a short, descriptive filename from the content (kebab-case, no spaces, .md extension)
3. Save the note to `scratch/<filename>.md` using `mcp__obsidian__create` with `file_text`
4. Format the note with a `# Title` heading and today's date (`YYYY-MM-DD`) at the top
5. Confirm the saved path to the user
