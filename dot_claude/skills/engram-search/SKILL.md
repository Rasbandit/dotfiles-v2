---
description: Search the user's personal knowledge base (Obsidian vault) for relevant information. Use when user asks "do I have notes on X", "search my vault", "find my notes about", or "check my engrams". ALSO trigger proactively any time you encounter an unfamiliar term, project name, person, concept, or acronym in the conversation — search first before asking for clarification or making assumptions.
argument-hint: <search query or topic>
---

Search the user's personal knowledge base for relevant context.

Query: $ARGUMENTS

## Detect the mode

**Explicit search** — the user directly asked you to search their vault. Show them the results.

**Ambient/proactive search** — you're searching to orient yourself mid-conversation (e.g., unfamiliar term, project, person, or concept). Do NOT interrupt the user to announce you're searching. Search silently, absorb the context, then continue your response informed by what you found. Only surface the fact that you searched if it meaningfully changes your answer.

---

## Explicit search

### 1. Search
```
mcp__engram__search_notes(query=<query>, limit=5)
```
If the query contains obvious category words (e.g., "health", "supplements", "work"), also fetch available tags:
```
mcp__engram__list_tags()
```
and re-run with relevant `tags` filter if it would meaningfully narrow results.

### 2. If results found
Show a clean list — title, path, and a 1–2 sentence excerpt of the most relevant part:

```
**[Note Title]**
Path: 2. Knowledge Vault/Health/...
> Excerpt showing the relevant part...
```

Then offer next steps: "Want me to read any of these in full?"

If the user says yes (or references result N), use:
```
mcp__engram__get_note(source_path=<path>)
```
Then summarize or quote the relevant sections — don't dump the full raw content unless asked.

### 3. If no results
Don't just suggest search terms. First try one automatic retry with a rephrased or broader query. If still nothing, tell the user clearly and suggest 2–3 related terms they could try.

---

## Ambient/proactive search

Run when you encounter something in the conversation you don't fully understand in the user's personal context — a project codename, a person's name, a product, a term that might have a specific meaning to them.

### 1. Search silently
```
mcp__engram__search_notes(query=<term or topic>, limit=3)
```

### 2. Synthesize
Read the top results. Extract the key facts that are relevant to the current conversation. Do not output a list — integrate the knowledge into your working context.

### 3. Respond
Continue your answer using the retrieved context. If what you found materially changes your understanding, briefly acknowledge it:
> "I pulled up your notes on [topic] — based on that, [adjusted response]."

If nothing useful was found, ask the user a targeted clarifying question rather than making assumptions.
