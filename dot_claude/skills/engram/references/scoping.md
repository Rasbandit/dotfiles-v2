# Scoping — Topic-to-Folder/Tag Resolution

Utility reference. Loaded by `search.md` and `create.md` when they need to resolve a topic scope. Not routed to directly by user intent.

---

## Core Rules

- **Soft bias, not a hard filter.** Scoped folders are searched first; the rest of the vault is always checked.
- **Never silently exclude results.** Surface out-of-scope results with a light label: `[outside scope]`.
- **Confirm once, then stay quiet.** After a scope is confirmed for a topic, never re-ask for the same topic.
- **Override wins immediately.** If the user says "search everywhere" or names a specific folder, skip resolution entirely and use their target.
- **Unknown topics are fine.** If a topic has no scope and no match is found, search the entire vault without friction.

---

## Resolution Order

When given a topic, resolve its scope as follows:

### 1. Check Config First

Look up the topic (case-insensitive) in `topicScopes` inside `~/.engram/skill-config.json`.

```json
{
  "topicScopes": {
    "computers": {
      "folders": ["2. Knowledge Vault/Linux/", "2. Knowledge Vault/DevOps/"],
      "tags": ["dev/linux", "hardware"]
    }
  }
}
```

If a mapping exists: use it. Skip to execution — do not re-ask.

### 2. Discover Tags and Folders (no existing mapping)

If no config mapping exists, discover what's in the vault:

**Tier 3 (CLI + Engram):**
```
mcp__engram__list_tags()
```

**Tier 2 (CLI only):**
```bash
obsidian tags counts
```

**Tier 1 (filesystem only):**
```bash
grep -r "^tags:" <vaultPath> --include="*.md" -h | sort | uniq -c | sort -rn
```

Then check vault folder names for partial, case-insensitive matches to the topic.

### 3. Suggest Scope Once

If tag or folder matches are found and no prior scope exists for this topic, ask the user **once** using `AskUserQuestion`:

```
"I'd scope 'computers' to Linux/ and DevOps/. Sound right?"
```

Include matched tags if relevant:
```
"I'd scope 'computers' to Linux/ and DevOps/ (tags: dev/linux, hardware). Sound right?"
```

### 4. Handle the Response

| User response | Action |
|---|---|
| Confirms | Store the suggested mapping in config (see below) |
| Corrects (gives different folders/tags) | Store their correction instead |
| Declines / "search everywhere" | Do not store; search the entire vault |

### 5. No Match Found

If no tags or folders match the topic: search the entire vault. Do not block, do not ask. Continue silently.

---

## Config Update Pattern

When storing a new or corrected topic scope:

1. Read current `~/.engram/skill-config.json`
2. Merge the new entry into `topicScopes` (do not overwrite other keys)
3. Write the file back

```json
{
  "topicScopes": {
    "computers": {
      "folders": ["2. Knowledge Vault/Linux/", "2. Knowledge Vault/DevOps/"],
      "tags": ["dev/linux", "hardware"]
    }
  }
}
```

- `folders` — paths relative to the vault root, trailing slash included
- `tags` — exact tag strings as they appear in the vault

---

## Creation Scoping

When a topic scope is active during note creation:

| Tier | Behavior |
|---|---|
| **Tier 3** | Use the scoped folder as the suggested path; pass it to `mcp__engram__suggest_folder` as validation/fallback |
| **Tier 2** | Use the scoped folder directly, or ask the user if the scoped path is ambiguous |
| **Tier 1** | Use the scoped folder directly, or ask the user |

Example: "Save a note about my Fedora setup" → topic "computers" → scope maps to `Linux/` → suggest creating in `2. Knowledge Vault/Linux/`.

---

## Override Handling

If the user explicitly names a folder or says "search everywhere" / "check my [folder] folder":

1. Skip resolution entirely
2. Use the user's explicit target as the search/creation path
3. Do not suggest storing this override as a scope
