#!/usr/bin/env bash
# Estimate tokens auto-loaded at session start for a project dir (default: cwd).
# chars/4 is a rough token estimate.
dir=${1:-$PWD}
slug=$(echo "$dir" | sed 's#/#-#g')
tok(){ [ -f "$1" ] && printf "%7d tok  %s\n" $(( $(wc -c < "$1") / 4 )) "$1"; }
echo "== instruction files"
tok ~/.claude/CLAUDE.md
d=$dir; while [ "$d" != "/" ]; do tok "$d/CLAUDE.md"; tok "$d/CLAUDE.local.md"; d=$(dirname "$d"); done
for sub in "$dir"/*/; do tok "${sub}CLAUDE.md"; done 2>/dev/null | sed 's/$/  (loads when files there are touched)/'
echo "== @imports (missing ones are dead weight to remove)"
grep -h '^@' ~/.claude/CLAUDE.md "$dir/CLAUDE.md" 2>/dev/null | while read -r imp; do f=${imp#@}; [ -f "$f" ] && tok "$f" || echo "   MISSING  $f"; done
echo "== auto memory index"
tok ~/.claude/projects/$slug/memory/MEMORY.md
echo "== SessionStart / UserPromptSubmit hooks (settings.json)"
jq -r '.hooks | to_entries[] | select(.key=="SessionStart" or .key=="UserPromptSubmit") | .key as $k | .value[] | .hooks[] | "\($k): \(.command[0:90])"' ~/.claude/settings.json
echo "== enabled plugins (each adds skills, agents, maybe hooks)"
jq -r '.enabledPlugins | to_entries[] | select(.value==true) | .key' ~/.claude/settings.json
echo "== MCP servers: check with 'claude mcp list'; every server adds tool names + instructions"
