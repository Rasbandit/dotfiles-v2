---
name: esde-steam-media
description: Download missing game artwork (covers, marquees, screenshots, physical media) and metadata for any ES-DE system using SteamGridDB API, Steam CDN, and web search fallback.
user_invocable: true
---

# ES-DE Media & Metadata Downloader

Download missing media and fill gamelist.xml metadata for any ES-DE game system.

## Trigger phrases
- "download steam media"
- "fill ES-DE gaps"
- "get missing artwork"
- "steam artwork"
- "ES-DE steam covers"
- "update steam metadata"
- "fill gamelist"
- "ports metadata"
- "ES-DE ports media"
- "audit covers"
- "upgrade covers"
- "check media quality"

## Instructions

1. Verify `$STEAMGRIDDB_API_KEY` is set (needed for Steam system; optional for others):
   ```bash
   echo "${STEAMGRIDDB_API_KEY:+set}"
   ```
   If empty and targeting steam, tell the user to run `source ~/.bash_secrets` or export the key.

2. Verify `requests` is available:
   ```bash
   python3 -c "import requests"
   ```
   If missing, install with `pip install requests`.

3. **For obscure/failing games:** Before running the script, do a `--dry-run --verbose` first.
   If there are games that failed in previous runs or look obscure (demos, early access, indie),
   research those games briefly (Steam store page, web search) and tell the user what they are
   and whether artwork/metadata is likely to exist. This sets expectations before downloading.

4. Run the downloader. Pass through any user-specified arguments:
   - `--system <name>` — ES-DE system (default: `steam`). E.g., `ports`, `n64`, etc.
   - `--dry-run` — show gaps without downloading
   - `--type <covers|marquees|screenshots|physicalmedia>` — limit to one media type
   - `--game "<name>"` — process only one game (by ROM filename stem)
   - `--media-only` — skip metadata update
   - `--metadata-only` — skip media download
   - `--verbose` — show per-file progress
   - `--audit` — check existing media for size/quality issues and show available upgrades
   - `--upgrade` — re-download flagged media that has better versions on SteamGridDB
   - `--report-gaps` — output uncached gaps as JSON (for AI batch processing)
   - `--mark-searched FILE` — mark gaps from a report as searched in the cache

   Default (no args from user): run with `--verbose` to show progress.

   ```bash
   python3 ~/Documents/claude-home/scripts/esde-steam-media.py $ARGUMENTS
   ```

5. **Web-search fallback for failures:** After the script runs, check for any
   `[MISS]` or `[SKEL]` entries (games where automated sources returned no data).

   For each failed game:
   a. Use `mcp__perplexity__search` or `WebFetch` to find: description, release date,
      developer, publisher, genre, and player count.
   b. Write a Python snippet to update the system's gamelist.xml directly,
      using `xml.etree.ElementTree`. Only fill empty fields — never overwrite existing data.
      The gamelist path is `~/ES-DE/gamelists/<system>/gamelist.xml`.
   c. Report what was filled to the user.

   **For non-Steam systems** (like `ports`), ALL games will show as `[MISS]` or `[SKEL]`
   since there are no automated API sources. This web-search step is the primary data source
   for these systems — research every game that has gaps.

6. Report the summary output to the user. If there were media failures, suggest running again
   with `--game` for specific titles, or explain why they failed (delisted, demo with no
   assets, etc.)

7. If any media was downloaded, regenerate miximages using the CLI generator:
   ```bash
   python3 ~/Documents/claude-home/scripts/esde-miximage-gen.py --system <system> --verbose
   ```
   Add `--overwrite` to regenerate all (e.g., after cover upgrades).
   This replicates ES-DE's built-in generator (ported from MiximageGenerator.cpp).

## Audit cache system

The script maintains `~/ES-DE/.audit-cache.json` to prevent repeated AI searches:
- Items marked `filled` are never re-searched
- Items marked `not_found` have a 30-day cooldown before re-searching
- Uninstalled games (no .desktop/.sh file) are pruned automatically

### Hourly cron

A cron wrapper at `~/Documents/claude-home/scripts/esde-audit-cron.sh` runs:
1. `--upgrade` (automated, free — SGDB/Steam CDN)
2. `--report-gaps` (cache-aware, prunes uninstalled)
3. One batched `claude -p` call for all remaining gaps (token-efficient, 7-day cooldown)
4. `--mark-searched` (updates cache so items aren't re-searched)
5. `esde-miximage-gen.py` — generates missing miximages for all systems
