# Search Operations

## Intent patterns

- "find notes about"
- "search vault", "search my vault", "search my notes"
- "what do I know about"
- "do I have notes on"
- "have I written about"
- "check my engrams"
- Unfamiliar term, project name, or person mentioned mid-conversation with no prior context

---

## Mode detection

Determine the mode before executing any search.

**Explicit** — user directly asked to search their vault. Surface results to the user.

**Ambient/proactive** — an unfamiliar term, project, or person appeared mid-conversation and you want context before responding. Search silently. Do not announce the search. Only mention it if results materially change your response.

---

## Operations

### search-explicit

User asked to find notes. Show results.

**Tier 3 (Full):**

1. Resolve topic scope — if the query contains obvious category words (health, work, tech, etc.), consult `references/scoping.md` to check for a matching scope in config.
2. Run semantic search: `mcp__engram__search_notes(query=<query>, limit=5)`
3. If category words are present: run `mcp__engram__list_tags()`, then re-run search with a relevant `tags` filter if it would meaningfully narrow results (i.e. a tag maps clearly to the category word).
4. Present results:
   ```
   **[Note Title]**
   Path: 2. Knowledge Vault/Health/...
   > Excerpt showing the relevant part...
   ```
5. Offer: "Want me to read any of these in full?"
6. If yes: `mcp__engram__get_note(source_path=<path>)` — summarize the relevant sections. Do not dump raw content.

**Tier 2 (CLI):**

1. Resolve topic scope (same as above, using config `topicScopes`).
2. If a scoped folder exists, search it first: `obsidian search "<query>" --folder "<scope>"`
3. Broaden if needed: `obsidian search "<query>"` or `obsidian search:context "<query>"` for surrounding context.
4. Present results in the same format as Tier 3.
5. Offer to read: `obsidian read "<note title>"`

**Tier 1 (Files):**

1. Resolve topic scope from config `topicScopes`.
2. If a scoped folder exists, search it first: `grep -ril "<query>" <vaultPath>/<scope>/`
3. Broaden if still needed: `grep -ril "<query>" <vaultPath>/`
4. For the top 5 matches, read the first ~20 lines of each file to extract an excerpt.
5. Present results in the same format as Tier 3.
6. Offer to read: read the full file and summarize relevant sections.

---

### search-ambient

A term, name, or concept appeared mid-conversation that you don't have context for. Search silently to orient yourself before responding.

**Tier 3 (Full):**

`mcp__engram__search_notes(query=<term>, limit=3)` — silently.

**Tier 2 (CLI):**

`obsidian search "<term>"` — silently.

**Tier 1 (Files):**

`grep -ril "<term>" <vaultPath>/` — silently.

**After searching:**

- If results are useful: absorb them and continue with an informed response. Surface the search only if it materially changes your answer — e.g., "I pulled up your notes on [topic] — based on that, [adjusted response]."
- If nothing useful: ask a targeted clarifying question instead of assuming. Do not say "I searched your vault."

---

### no-results handling

Applies to all tiers and both modes.

1. Auto-retry once with a rephrased or broader query (try synonyms, remove qualifiers, use a parent concept).
2. If still nothing: tell the user clearly, then suggest 2–3 related terms they could try.
3. Do not just say "nothing found" — always give an actionable next step.

Example:
```
No notes found for "ashwagandha". I also tried "adaptogens" — still nothing.
You could try: "supplements", "nootropics", or "health stack".
```

---

## Examples

1. **"do I have any notes about docker?"**
   Explicit search. Query: `docker`. Run search, present results with titles, paths, and excerpts. Offer to read any in full.

2. **User mentions "the phoenix protocol" mid-conversation with no prior context**
   Ambient search. Query: `phoenix protocol`. Silent. If a note is found, integrate its context into your response naturally. If nothing is found, continue without mentioning the search.

3. **"search my vault for anything about health and supplements"**
   Explicit search with category words detected ("health", "supplements"). Resolve scope via `scoping.md`. Run semantic search, then filter by health-related tags if available. Present results.

4. **"what do I know about my morning routine?"**
   Explicit search. Query: `morning routine`. If no results, retry with `habits` or `daily routine`. Suggest broader terms if still nothing.
