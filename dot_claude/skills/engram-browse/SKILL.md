---
description: Explore and orient within the personal knowledge base (Obsidian vault). Use when user asks "what do I have on X", "show me my vault", "what folders exist", "what tags do I use", "what's in my health folder", "give me an overview of my notes", or any time they want to navigate or discover what's in the vault rather than search for specific content. Prefer this over engram-search when the user wants to browse or get an overview rather than find a specific note.
argument-hint: <topic, folder, or "overview">
---

Help the user orient and navigate their knowledge base.

Request: $ARGUMENTS

## Detect the intent

| Intent | Action |
|--------|--------|
| "what do I have on X" / topic query | [Topic browse](#topic-browse) |
| "show my vault" / "what folders" / overview | [Vault overview](#vault-overview) |
| "what's in [folder]" / specific folder | [Folder drill-down](#folder-drill-down) |
| "what tags do I use" / tag listing | [Tag browse](#tag-browse) |

When in doubt, default to **Topic browse** — it covers the most ground.

---

## Topic browse

When the user asks what they have on a subject, check both angles — tags tell you the topic density, folders tell you where content lives.

```
mcp__engram__list_tags()
mcp__engram__list_folders()
```

From the results, surface:
1. **Tags** that match or relate to the topic (with counts)
2. **Folders** whose name overlaps the topic

Present concisely — don't dump the full lists. Then offer next steps:
- "Want me to search inside any of these?" → hand off to `engram-search`
- "Want to see what's in [folder]?" → drill down with `list_folder`

---

## Vault overview

```
mcp__engram__list_folders()
```

The raw folder list is long — don't paste it. Instead, group by top-level section and summarize note counts:

```
**1. Alignment** — goals, reviews, backlog (N notes)
**2. Knowledge Vault** — health, tech docs, books, personal... (N notes)
**3. Journal** (N notes)
**4. Work Log** (N notes)
```

Then list the top-level Knowledge Vault sub-areas with their note counts so the user can see where content is concentrated. Invite them to drill into any area.

---

## Folder drill-down

```
mcp__engram__list_folder(folder=<path>)
```

If the user named a folder loosely (e.g., "health"), find the closest match from `list_folders` first, then call `list_folder` with the exact path.

Show the note titles as a clean list. If there are subfolders worth exploring, mention them. Offer to open any note with `engram-search` or `engram-update`.

---

## Tag browse

```
mcp__engram__list_tags()
```

Show the tags sorted by count (the API returns them this way). Group visually if there are obvious clusters (e.g., health-related, tech-related). For tags with high counts, offer to search by tag:

> "Want me to pull all notes tagged `supplements`?"

If yes, run:
```
mcp__engram__search_notes(query=<tag or related phrase>, tags=[<tag>], limit=10)
```
