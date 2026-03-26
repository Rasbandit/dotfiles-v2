# Browse Operations

## Intent patterns

- "what's in my vault", "show me my vault", "vault structure"
- "show folders", "list my notes", "what topics do I have"
- "what do I have on X" (broad exploration, not a targeted search)
- "what tags", "what tags do I use"
- "show me the [folder] folder", "what's in [folder]"

---

## Operations

### topic-browse

User asks what they have on a broad subject — check both tags and folders.

**Tier 3 (Full):**

1. Call `mcp__engram__list_tags()` and `mcp__engram__list_folders()` in parallel.
2. Surface tags that match or relate to the topic (with counts).
3. Surface folders whose names overlap the topic.
4. Present concisely — do not dump full lists. Highlight the most relevant matches.
5. Offer next steps:
   > "Want me to search inside any of these?" or "Want to see what's in [folder]?"

**Tier 2 (CLI):**

1. Run `obsidian tags counts` and `obsidian folders` in parallel.
2. Same filtering and presentation logic as Tier 3.
3. Offer the same next steps.

**Tier 1 (Files):**

1. Tags: parse frontmatter across vault files (`grep -r "^tags:" <vaultPath>/`) and collect matches for the topic.
2. Folders: `ls <vaultPath>/` and check folder names for overlap with the topic.
3. Same presentation and next-step offer as Tier 3.

---

### vault-overview

High-level vault structure overview.

**Tier 3 (Full):** `mcp__engram__list_folders()`

**Tier 2 (CLI):** `obsidian vault` or `obsidian folders`

**Tier 1 (Files):** `ls <vaultPath>/`

Do not paste raw folder lists. Group by top-level section and summarize note counts:

```
**1. Alignment** — goals, reviews, backlog (N notes)
**2. Knowledge Vault** — health, tech docs, books, personal... (N notes)
**3. Journal** (N notes)
```

List the top Knowledge Vault sub-areas with their note counts. Invite the user to drill into any area.

---

### folder-drill

Contents of a specific folder the user named.

**Tier 3 (Full):** `mcp__engram__list_folder(folder=<path>)`

**Tier 2 (CLI):** `obsidian folders --path "<folder>"`

**Tier 1 (Files):** `ls <vaultPath>/<folder>/`

If the user named a folder loosely (e.g. "health"), fuzzy-match against available folders first, then drill into the exact path. Show note titles as a clean list. Mention any subfolders worth exploring. Offer to open, read, or search any note.

---

### tag-browse

Display and explore the vault's tags.

**Tier 3 (Full):** `mcp__engram__list_tags()`

**Tier 2 (CLI):** `obsidian tags counts`

**Tier 1 (Files):** Parse frontmatter across vault files, collect and count all tags.

Sort by count. Group visually if there are obvious clusters (health-related, tech-related, etc.). For high-count tags, offer to search by tag:

> "Want me to pull all notes tagged `supplements`?"

If yes:
- **Tier 3:** `mcp__engram__search_notes(query=<tag or related phrase>, tags=[<tag>], limit=10)`
- **Tier 2:** `obsidian search "<tag>"` or equivalent tag filter
- **Tier 1:** `grep -rl "tags:.*<tag>" <vaultPath>/` then list matches

---

## Examples

1. **"what's in my vault?"** → vault-overview
2. **"what do I have on health?"** → topic-browse: filter tags and folders for "health", surface matches, offer to drill deeper
3. **"show me the Linux folder"** → folder-drill: fuzzy-match "Linux" against folders, list contents, offer to read any note
4. **"what tags do I use?"** → tag-browse: list all tags sorted by count, group by theme, offer tag-based search

---

## Reference: Existing engram-browse tool signatures

Preserve these exact signatures in Tier 3:

- `mcp__engram__list_tags()` — all tags with counts
- `mcp__engram__list_folders()` — top-level vault structure
- `mcp__engram__list_folder(folder=<path>)` — contents of a specific folder
- `mcp__engram__search_notes(query=<phrase>, tags=[<tag>], limit=10)` — tag-scoped semantic search
