# Task Operations

## Intent patterns

- "my tasks"
- "mark done", "mark complete"
- "what's todo", "what tasks do I have"
- "show incomplete tasks", "show all my tasks"
- "toggle task"
- "show tasks"
- "add a task"
- "complete task"
- "task list"

---

## Operations

### list-tasks

List incomplete or completed tasks from the vault.

**Tier 3 (Full):**

1. Determine scope — check if user wants incomplete only or include completed tasks.
2. Run CLI command:
   - Incomplete only: `obsidian tasks`
   - Include completed: `obsidian tasks --completed`
3. Present results as a clean checklist:
   ```
   - [ ] Task text here
     Source: 2. Knowledge Vault/Work/Project.md

   - [x] Completed task
     Source: 2. Knowledge Vault/Work/Project.md
   ```
4. If no tasks: say "No tasks found" and suggest where they might add one.

**Tier 2 (CLI):**

Same as Tier 3 (use `obsidian tasks` CLI).

**Tier 1 (Files):**

1. Incomplete tasks: `grep -rn "- \[ \]" <vaultPath>/`
2. Completed tasks: `grep -rn "- \[x\]" <vaultPath>/`
3. Parse grep results to extract:
   - Task text (the part after `- [ ]` or `- [x]`)
   - Source file path
4. Present in the same format as Tier 3.
5. If no tasks: say "No tasks found."

---

### toggle-task

Mark a task as done (or undo completion).

**Tier 3 (Full):**

1. Identify the task from user input (exact task text or a nearby match).
2. Run: `obsidian task "<task text>" --toggle`
3. Confirm with one line:
   ```
   Toggled: "[task text]" → done [2. Knowledge Vault/Work/Project.md]
   ```
   Or if undone:
   ```
   Toggled: "[task text]" → undone [2. Knowledge Vault/Work/Project.md]
   ```

**Tier 2 (CLI):**

Same as Tier 3 (use `obsidian task` CLI).

**Tier 1 (Files):**

1. Search for the task in the vault:
   - `grep -rn "<task text>" <vaultPath>/` (or a substring if exact match fails)
2. Identify the matching line and file path.
3. Read the file, locate the exact line containing `- [ ]` or `- [x]`.
4. Toggle: replace `[ ]` with `[x]` or vice versa.
5. Write back using Edit tool (or write_file if preferred).
6. Confirm with the same one-line format as above.

---

### filter-tasks

Filter tasks by tag, folder, or other criteria.

**Tier 3 (Full):**

1. Determine the filter type (tag, folder, or other criteria).
2. Run appropriate command:
   - By tag: `obsidian tasks --tag "<tag>"`
   - By folder: `obsidian tasks --folder "<folder>"`
3. Present results in the same checklist format as `list-tasks`.
4. If no results: suggest broadening the filter or checking task counts per folder/tag.

**Tier 2 (CLI):**

Same as Tier 3 (use `obsidian tasks` with `--tag` or `--folder` flags).

**Tier 1 (Files):**

1. **By folder:** `grep -rn "- \[ \]" <vaultPath>/<folder>/`
2. **By tag:**
   - Two-step process:
     1. Find files with the tag in frontmatter: `grep -l "^tags:.*<tag>" <vaultPath>/**/*.md`
     2. Search for tasks in those files: `grep -n "- \[ \]" <file1> <file2> ...`
3. Parse and present results in checklist format (same as `list-tasks`).

---

## Examples

1. **"what tasks do I have?"**
   → `list-tasks` (incomplete only). Show all incomplete tasks with source paths.

2. **"mark 'review PR' as done"**
   → `toggle-task` with task text "review PR". Confirm the toggle and show the source.

3. **"show all my tasks including completed ones"**
   → `list-tasks` with completed flag. Show both incomplete and completed tasks.

4. **"show tasks in my work folder"**
   → `filter-tasks` by folder. Filter to tasks in the work-related folder and list them.

5. **"what tasks are tagged with #urgent?"**
   → `filter-tasks` by tag. Filter to tasks tagged with "urgent" and list them.

6. **"my todo"**
   → `list-tasks` (incomplete only). Friendly alias for task list.
