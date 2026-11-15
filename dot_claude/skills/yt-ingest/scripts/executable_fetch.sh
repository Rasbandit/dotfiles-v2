#!/usr/bin/env bash
# fetch.sh URL TMPDIR
# Downloads metadata + json3 captions + top 50 comments via yt-dlp.
# Falls back to vtt if json3 missing, then to whisper MCP path (caller handles).
set -euo pipefail

URL="${1:?usage: fetch.sh URL TMPDIR}"
TMPDIR="${2:?usage: fetch.sh URL TMPDIR}"
mkdir -p "$TMPDIR"
cd "$TMPDIR"

# Reject cloud IPs — yt-dlp gets blocked from AWS/GCP/Azure ranges.
case "$(hostname)" in
  *fastraid*|*slowraid*)
    echo "ERR: yt-ingest must run on Claw, not $(hostname). Cloud IPs are blocked by YouTube." >&2
    exit 2
    ;;
esac

# Extract video ID for output naming.
ID=$(echo "$URL" | grep -oE '(v=|youtu\.be/|/shorts/)[A-Za-z0-9_-]{11}' | grep -oE '[A-Za-z0-9_-]{11}$' | head -1)
if [ -z "$ID" ]; then
  echo "ERR: could not extract video ID from URL: $URL" >&2
  exit 3
fi

COMMON_ARGS=(
  --skip-download
  --write-info-json
  --write-comments
  --extractor-args "youtube:max_comments=50,all,0,0;comment_sort=top"
  --sleep-interval 2
  --retries 3
  -o "%(id)s"
  "$URL"
)

# Try json3 first — clean per-event captions, no rolling duplicates.
if ! yt-dlp --write-auto-sub --sub-lang en --sub-format json3 "${COMMON_ARGS[@]}" 2>&1; then
  echo "WARN: json3 fetch failed, retrying with vtt fallback" >&2
  yt-dlp --write-auto-sub --sub-lang en --sub-format vtt "${COMMON_ARGS[@]}"
fi

# Verify we have at least info.json + some caption form.
if [ ! -f "$ID.info.json" ]; then
  echo "ERR: info.json missing after fetch — yt-dlp likely blocked or video unavailable" >&2
  exit 4
fi

if [ ! -f "$ID.en.json3" ] && [ ! -f "$ID.en.vtt" ]; then
  echo "WARN: no captions found — caller should escalate to whisper MCP" >&2
  # Extract audio for whisper. Caller invokes mcp__whisper__transcribe_audio on the mp3.
  yt-dlp -x --audio-format mp3 -o "%(id)s" "$URL" 2>&1
  if [ ! -f "$ID.mp3" ]; then
    echo "ERR: audio extraction failed — cannot transcribe" >&2
    exit 5
  fi
  echo "INFO: audio extracted to $TMPDIR/$ID.mp3 — call whisper MCP" >&2
fi

echo "OK: $ID fetched to $TMPDIR" >&2
echo "$ID"
