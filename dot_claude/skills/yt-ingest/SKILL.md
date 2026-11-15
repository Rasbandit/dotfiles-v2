---
name: yt-ingest
description: >
  Ingest a YouTube video into the current Obsidian vault as a structured fact-card
  optimized for cross-video synthesis: atomic timestamped claims, cited evidence,
  protocols, open questions, and synthesized comment insights — no full transcript dump.

  Auto-trigger when the user shares a youtube.com/watch, youtu.be, or youtube.com/shorts URL
  AND the conversational context implies capture intent: "save this video", "add this to the
  vault", "ingest this", "I want to remember this", "watch later", or just pasting a URL with
  no other context.

  DO NOT trigger when the user is clearly using a YouTube link to discuss the video, ask
  questions about its content, or share it as a reference within an unrelated task. When intent
  is ambiguous, confirm before running.

  Also fires on explicit invocation: "/yt-ingest <url>".
argument-hint: <youtube-url>
---

# YouTube → Obsidian Ingestion

Pipeline: yt-dlp fetches metadata + auto-captions (json3) + top 50 comments → render.py builds a markdown skeleton with placeholders → Claude fills summaries by reading the transcript → file lands in vault per `config/vault-routing.json`.

URL: $ARGUMENTS

## Workflow

### 1. Extract video ID
Parse the URL with regex `(?:v=|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})`. Reject if no match — ask user for a valid YouTube URL.

### 2. Resolve destination
Run `python3 ~/.claude/skills/yt-ingest/scripts/vault_resolve.py "$PWD"`. Output is JSON with `vault`, `destination`, `frontmatter_extra`. If `error: no vault found`, ask the user which vault to use (list known keys from `config/vault-routing.json`) or abort.

### 3. Idempotency check
`grep -rl "source: https://youtu.be/<ID>" "<vault>"`. If a note exists, ask the user: skip / regenerate (overwrite) / open existing.

### 4. Fetch
```bash
TMPDIR=$(mktemp -d -t yt-ingest-XXXX)
~/.claude/skills/yt-ingest/scripts/fetch.sh "<URL>" "$TMPDIR"
```
Script handles json3 captions, comments, info.json, retries on 429, falls back to vtt then to whisper MCP if no captions. On non-zero exit, surface stderr and stop.

### 5. Render skeleton
```bash
python3 ~/.claude/skills/yt-ingest/scripts/render.py "<ID>" "$TMPDIR" --frontmatter-extra '<json from step 2>' > "$TMPDIR/<ID>.draft.md"
```
Produces a markdown file with `_TODO:_` placeholders for Summary, Key Takeaways, and per-chapter summaries.

### 6. Fill the draft

The draft is structured as a **fact-card** for cross-video synthesis, not a standalone summary. Future-Claude will read 5+ of these on the same topic and dedupe / contradict claims across them. Optimize accordingly:

- **Atomic > narrative**. One fact per claim, not paragraphs.
- **Provenance > prose**. Always tag confidence (`[study]`, `[own-study]`, `[mechanism]`, `[clinical]`, `[opinion]`, `[anecdote]`) and link the timestamp.
- **Synthesize, don't dump**. Comments get themed and weighted by likes, not pasted raw.

The draft includes the full transcript and all 50 raw comments embedded as HTML comments (between `<!-- TRANSCRIPT-START -->` / `<!-- TRANSCRIPT-END -->` and `<!-- COMMENTS-START -->` / `<!-- COMMENTS-END -->`). Read both, then:

**Frontmatter placeholders**:
- `topics:` — 3–6 kebab-case slugs that another video on this subject would also tag (e.g. `[sibo, biofilm, antimicrobial-resistance]`). These are the cross-link backbone.
- `people:` — named experts/researchers/clinicians cited or interviewed.
- `studies-cited:` — `"AuthorYear — Journal — Title"` per study mentioned. Mark `unspecified` for hand-waved citations.
- `products-mentioned:` — supplements, drugs, branded protocols by exact name.

**Body sections**:
- **Bottom line**: 1–2 sentences. What does this video *add* to the topic? Not a summary of the video.
- **Claims**: 5–12 numbered atomic statements. Each tagged + timestamped. Cite the source the speaker cites.
- **Protocols mentioned**: bulleted, with dose/duration/sequence where stated. Omit section if none.
- **Evidence cited**: table of source / finding / claim-supported. Omit if video makes no external citations.
- **Open questions / hooks for cross-reading**: explicit gaps, weak evidence, counter-arguments not addressed, things to check against other videos. **This is the synthesis hook — don't skip it.**
- **Insights from comments**: synthesize the 50 raw comments. Group into alt-protocols / adjacent-conditions / corrections / author-resources. Drop praise. Keep anything that's a data point or a lead. Like-counts are signal weight.
- **Connects to**: for each `topics:` slug, run `grep -rl "topics:.*<slug>" "<vault>/"` and list matching notes as `[[wikilinks]]`. Empty list is fine on the first video — Obsidian backlinks will populate as more land.

### 6b. Strip embedded transcript + raw comments
After all `_TODO_` placeholders are filled, delete the regions between (and including) the `<!-- TRANSCRIPT-START -->` / `<!-- TRANSCRIPT-END -->` markers and the `<!-- COMMENTS-START -->` / `<!-- COMMENTS-END -->` markers. Also delete the chapter-index HTML comments. Final note must contain none of these — the source URL + per-claim timestamp deep-links are the evidence chain.

### 7. Land in vault
```bash
SLUG=$(python3 -c "import sys, re; t=sys.argv[1]; print(re.sub(r'[/\\\\:*?\"<>|]', '', t).strip())" "<title>")
DEST="<destination>/<upload_date_iso> $SLUG.md"
mkdir -p "$(dirname "$DEST")"
mv "$TMPDIR/<ID>.draft.md" "$DEST"
```

### 8. Report
Print the absolute path of the created note. Offer to open it.

## Frontmatter contract (Health vault)

```yaml
tags: [health, video, reference]
date: <YYYY-MM-DD upload>
source: https://youtu.be/<id>
channel: "<channel>"
duration: "<hh:mm:ss>"
synthesis: unprocessed
```

`synthesis: unprocessed` lets the note flow into the Health vault's Intake Queue. Other vaults override via `vault-routing.json`.

## Failure modes

| Symptom | Fix |
|---|---|
| `429` / "try again later" | fetch.sh retries 3× with 5–30s backoff; if still failing, wait and retry the skill |
| No captions exist | fetch.sh extracts mp3, calls `mcp__whisper__transcribe_audio`. Warn user: 1–5 min/hr of video |
| Comments disabled | render.py skips the section, doesn't fail |
| Live stream / premiere | reject early — transcripts not stable |
| Age-restricted / members-only | fail with cookies-export instructions: `yt-dlp --cookies-from-browser firefox` |
| Cloud-IP block | refuse to run if `hostname` matches FastRaid/SlowRaid; only Claw is safe |

## Notes for future maintenance

- `youtube-transcript-api` is a planned secondary fallback (not yet installed). Add to fetch.sh when needed.
- yt-dlp version was 2026.03.17 at skill creation; YouTube extractor breaks every few months — `dnf upgrade yt-dlp` first if any stage fails.
- json3 caption format gives clean per-event fragments with no rolling-caption duplicates. Do not switch back to vtt-only.
