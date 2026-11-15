#!/usr/bin/env python3
"""Render yt-dlp info.json + captions into a markdown skeleton with TODO placeholders.

Usage:
  render.py VID TMPDIR [--frontmatter-extra JSON] [--out PATH]

Output: writes a draft .md (skeleton) to PATH (default: TMPDIR/<VID>.draft.md) and
prints the path on stdout. Draft contains _TODO:_ placeholders for Claude to fill.
"""
import argparse
import json
import re
import sys
from pathlib import Path

INLINE_TAG = re.compile(r"<\d{2}:\d{2}:\d{2}\.\d{3}><c>|</c>|<c[^>]*>")
TS_LINE = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.\d{3} --> (\d{2}):(\d{2}):(\d{2})\.\d{3}")

def parse_json3(path: Path) -> list[tuple[float, str]]:
    """YouTube auto-caption json3: each event = one clean fragment, no rolling repetition."""
    data = json.loads(path.read_text())
    out: list[tuple[float, str]] = []
    for ev in data.get("events", []):
        if ev.get("aAppend"):
            continue
        segs = ev.get("segs") or []
        text = "".join(s.get("utf8", "") for s in segs).replace("\n", " ").strip()
        if not text:
            continue
        out.append((ev["tStartMs"] / 1000, text))
    return out

def parse_vtt(path: Path) -> list[tuple[float, str]]:
    """Fallback when json3 unavailable. Strips inline word-timing tags and exact dupes."""
    out: list[tuple[float, str]] = []
    seen_text: str | None = None
    cur_start: float | None = None
    cur_lines: list[str] = []
    for raw in path.read_text().splitlines():
        line = raw.rstrip()
        m = TS_LINE.match(line)
        if m:
            if cur_start is not None and cur_lines:
                text = INLINE_TAG.sub("", " ".join(cur_lines)).strip()
                if text and text != seen_text:
                    out.append((cur_start, text))
                    seen_text = text
            h, mn, s = int(m.group(1)), int(m.group(2)), int(m.group(3))
            cur_start = h * 3600 + mn * 60 + s
            cur_lines = []
        elif line and not line.startswith(("WEBVTT", "Kind:", "Language:")) and "-->" not in line:
            cur_lines.append(line)
    if cur_start is not None and cur_lines:
        text = INLINE_TAG.sub("", " ".join(cur_lines)).strip()
        if text and text != seen_text:
            out.append((cur_start, text))
    return out

def fmt_ts(seconds: float) -> str:
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    return f"{h}:{m:02d}:{sec:02d}" if h else f"{m}:{sec:02d}"

def slice_by_chapters(snippets, chapters):
    if not chapters:
        bucket: dict[int, list] = {}
        for start, text in snippets:
            bucket.setdefault(int(start // 300), []).append((start, text))
        return [
            {"title": f"{fmt_ts(k*300)}–{fmt_ts((k+1)*300)}", "start_time": k*300, "snippets": v}
            for k, v in sorted(bucket.items())
        ]
    out = []
    for ch in chapters:
        ch_snips = [(s, t) for s, t in snippets if ch["start_time"] <= s < ch["end_time"]]
        out.append({"title": ch["title"], "start_time": ch["start_time"], "snippets": ch_snips})
    return out

def render_frontmatter(info: dict, vid: str, upload_iso: str, extra: dict) -> list[str]:
    """Build YAML frontmatter. `extra` keys override defaults; `tags` always merges.

    Includes Claude-fill placeholders for cross-video synthesis backbone:
    topics, people, studies-cited, products-mentioned.
    """
    lines = ["---"]
    tags = extra.get("tags", ["video"])
    lines.append("tags: [" + ", ".join(tags) + "]")
    lines.append(f"date: {upload_iso}")
    lines.append(f"source: https://youtu.be/{vid}")
    lines.append(f'channel: "{info.get("channel", "")}"')
    lines.append(f'duration: "{info.get("duration_string", "")}"')
    for k, v in extra.items():
        if k == "tags":
            continue
        if isinstance(v, str):
            lines.append(f"{k}: {v}")
        else:
            lines.append(f"{k}: {json.dumps(v)}")
    # Synthesis-backbone placeholders — Claude fills these.
    lines.append("topics: []  # TODO Claude: 3-6 topic slugs (kebab-case) for cross-vault linking")
    lines.append("people: []  # TODO Claude: named experts/researchers/clinicians mentioned")
    lines.append("studies-cited: []  # TODO Claude: 'AuthorYear — Journal — Title' per study")
    lines.append("products-mentioned: []  # TODO Claude: specific products, supplements, protocols by name")
    lines.append("---")
    return lines

def render_chapter_index(snippets: list, chapters: list, vid: str) -> list[str]:
    """Compact chapter index with snippet counts. Helps Claude locate evidence in transcript."""
    sliced = slice_by_chapters(snippets, chapters)
    out = ["<!-- chapter index for Claude — strip after fill -->"]
    for ch in sliced:
        ts = fmt_ts(ch["start_time"])
        out.append(f"<!-- {ts} {ch['title']} | {len(ch['snippets'])} snippets -->")
    return out

def render_raw_transcript_for_claude(snippets: list) -> list[str]:
    """Raw transcript embedded as HTML comment — Claude sees it, final note doesn't.

    Production note: the final .md should NOT contain this. The Skill workflow strips
    everything between the <!-- TRANSCRIPT-START --> and <!-- TRANSCRIPT-END --> markers
    after Claude fills the placeholders.
    """
    out = ["<!-- TRANSCRIPT-START — strip after fill -->"]
    for start, text in snippets:
        out.append(f"<!-- [{fmt_ts(start)}] {text} -->")
    out.append("<!-- TRANSCRIPT-END -->")
    return out

def render_raw_comments_for_claude(comments: list) -> list[str]:
    """All 50 comments embedded as HTML comments — Claude reads, synthesizes, then strips."""
    out = ["<!-- COMMENTS-START — strip after synthesis -->"]
    for c in comments:
        text = (c.get("text") or "").replace("\n", " ").replace("-->", "→").strip()
        likes = c.get("like_count", 0)
        author = c.get("author", "")
        pin = " PINNED" if c.get("is_pinned") else ""
        out.append(f"<!-- {likes:>4} likes | {author}{pin} | {text} -->")
    out.append("<!-- COMMENTS-END -->")
    return out

def render(info: dict, snippets: list, vid: str, frontmatter_extra: dict) -> str:
    chapters = info.get("chapters") or []
    upload = info.get("upload_date", "")
    upload_iso = f"{upload[0:4]}-{upload[4:6]}-{upload[6:8]}" if len(upload) == 8 else upload

    lines = render_frontmatter(info, vid, upload_iso, frontmatter_extra)
    lines += [
        "",
        f"# {info.get('title', '')}",
        "",
        f"**[{info.get('channel','')}]({info.get('channel_url','')})** · {upload_iso} · {info.get('duration_string','')} · [Watch](https://youtu.be/{vid})",
        "",
        "## Bottom line",
        "_TODO Claude: 1-2 sentences. What does this video add to the body of knowledge on this topic?_",
        "",
        "## Claims",
        "_TODO Claude: numbered atomic claims. Each tagged `[study|own-study|mechanism|clinical|opinion|anecdote]` and ending with a `[mm:ss](https://youtu.be/" + vid + "?t=Ns)` deep-link. Aim for 5-12. Atomic = one fact per claim, no compound sentences. Cite the source the speaker cites if any._",
        "",
        "1. _TODO_",
        "",
        "## Protocols mentioned",
        "_TODO Claude: bullet list of specific protocols, with dose / duration / sequencing where stated. Skip if video has none._",
        "",
        "## Evidence cited",
        "_TODO Claude: table | Source | Finding | Used to support | — one row per cited paper or dataset. Mark `unspecified` for hand-waved citations. Skip if no external evidence cited._",
        "",
        "| Source | Finding | Used to support |",
        "|---|---|---|",
        "| _TODO_ | | |",
        "",
        "## Open questions / hooks for cross-reading",
        "_TODO Claude: bullets — gaps, weak evidence, unaddressed counter-arguments, things that should be checked against other videos on this topic. This is the synthesis hook._",
        "",
        "## Insights from comments",
        "_TODO Claude: synthesize the 50 raw comments below. Group into:_",
        "- **User-reported alternative protocols** (with like counts as signal weight)",
        "- **Adjacent conditions / cascades surfaced**",
        "- **Corrections / dissents to the video**",
        "- **Author resources** (pinned, links to follow up)",
        "",
        "_Drop pure praise. Drop content-free agreement. Keep anything that's a data point or a lead._",
        "",
        "## Connects to",
        "_TODO Claude: after filling `topics:` frontmatter, run `grep -rl 'topics:.*<slug>' '<vault>/'` for each topic and list matching notes here as `[[wikilinks]]`. Empty if none yet — they'll backfill via Obsidian backlinks as more videos land._",
        "",
        "---",
    ]
    lines += render_chapter_index(snippets, chapters, vid)
    lines += render_raw_transcript_for_claude(snippets)
    lines += render_raw_comments_for_claude(info.get("comments") or [])
    return "\n".join(lines)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("vid")
    ap.add_argument("tmpdir")
    ap.add_argument("--frontmatter-extra", default="{}", help="JSON dict merged into frontmatter")
    ap.add_argument("--out", default=None, help="Output .md path (default: TMPDIR/VID.draft.md)")
    args = ap.parse_args()

    tmp = Path(args.tmpdir)
    info_path = tmp / f"{args.vid}.info.json"
    if not info_path.exists():
        print(f"ERR: {info_path} missing — run fetch.sh first", file=sys.stderr)
        return 1
    info = json.loads(info_path.read_text())

    json3 = tmp / f"{args.vid}.en.json3"
    vtt = tmp / f"{args.vid}.en.vtt"
    if json3.exists():
        snippets = parse_json3(json3)
        src = "json3"
    elif vtt.exists():
        snippets = parse_vtt(vtt)
        src = "vtt"
    else:
        print("ERR: no captions (.json3 or .vtt) — caller must run whisper fallback first", file=sys.stderr)
        return 2

    extra = json.loads(args.frontmatter_extra)
    out_md = render(info, snippets, args.vid, extra)
    out_path = Path(args.out) if args.out else tmp / f"{args.vid}.draft.md"
    out_path.write_text(out_md)
    print(f"# parsed {len(snippets)} snippets from {src}", file=sys.stderr)
    print(f"# wrote {out_path} ({len(out_md)} bytes)", file=sys.stderr)
    print(out_path)
    return 0

if __name__ == "__main__":
    sys.exit(main())
