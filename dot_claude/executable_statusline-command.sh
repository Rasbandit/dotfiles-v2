#!/usr/bin/env bash
input=$(cat)

cwd_raw=$(echo "$input" | jq -r '.cwd // empty')

# Compress path: abbreviate $HOME to ~, keep last 3 segments
compress_path() {
  local p="$1"
  p="${p/#$HOME/~}"
  # Count segments (split on /)
  local IFS='/'
  read -ra parts <<< "$p"
  local n="${#parts[@]}"
  if [ "$n" -le 4 ]; then
    echo "$p"
  else
    # Keep tilde/root prefix + ellipsis + last 2 segments
    echo "${parts[0]}/.../${parts[n-2]}/${parts[n-1]}"
  fi
}
cwd=$(compress_path "$cwd_raw")
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
# Calculate actual context tokens: uncached + cache_creation + cache_read
ctx_tokens=$(echo "$input" | jq -r '
  .context_window.current_usage |
  if . then
    ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))
  else 0 end
')
ctx_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Session duration ---
session_file="/tmp/claude-session-start-${PPID}"
if [ ! -f "$session_file" ]; then
  date +%s > "$session_file"
fi
session_start=$(cat "$session_file")
now_ts=$(date +%s)
elapsed=$(( now_ts - session_start ))
elapsed_hrs=$(( elapsed / 3600 ))
elapsed_mins=$(( (elapsed % 3600) / 60 ))
if [ "$elapsed_hrs" -gt 0 ]; then
  session_dur="${elapsed_hrs}h${elapsed_mins}m"
else
  session_dur="${elapsed_mins}m"
fi

# Color helpers
RESET='\033[00m'
BOLD='\033[01m'
DIM='\033[02m'
GREEN='\033[01;32m'
BLUE='\033[01;34m'
YELLOW='\033[01;33m'
CYAN='\033[01;36m'
MAGENTA='\033[01;35m'
RED='\033[01;31m'
WHITE='\033[01;37m'

SEP="${DIM} | ${RESET}"

# --- Section 1: time + session duration ---
printf "${CYAN}%s${RESET} ${YELLOW}(%s)${RESET}" "$(date +%H:%M)" "$session_dur"

# --- Section 2: working directory ---
if [ -n "$cwd" ]; then
  printf "${SEP}${BLUE}%s${RESET}" "$cwd"
fi

# --- Section 3: git branch + file counts ---
if [ -n "$cwd_raw" ]; then
  branch=$(git -C "$cwd_raw" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    porcelain=$(git -C "$cwd_raw" --no-optional-locks status --porcelain 2>/dev/null)
    staged=0; modified=0; untracked=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      x="${line:0:1}"; y="${line:1:1}"
      [ "$x" != "?" ] && [ "$x" != " " ] && [ "$x" != "!" ] && staged=$(( staged + 1 ))
      [ "$y" = "M" ] || [ "$y" = "D" ] && modified=$(( modified + 1 ))
      [ "$x" = "?" ] && untracked=$(( untracked + 1 ))
    done <<< "$porcelain"
    git_extra=""
    [ "$modified"  -gt 0 ] && git_extra="${git_extra} ${RED}*${modified}${RESET}"
    [ "$staged"    -gt 0 ] && git_extra="${git_extra} ${GREEN}+${staged}${RESET}"
    [ "$untracked" -gt 0 ] && git_extra="${git_extra} ${DIM}?${untracked}${RESET}"
    printf "${SEP}${YELLOW} %s${RESET}%b" "$branch" "$git_extra"
  fi
fi

# --- Section 4: language versions (only when relevant files exist in cwd) ---
if [ -n "$cwd_raw" ]; then
  lang_parts=""

  # Node.js
  if [ -f "$cwd_raw/package.json" ] || [ -f "$cwd_raw/.nvmrc" ] || [ -f "$cwd_raw/.node-version" ]; then
    node_ver=$(node --version 2>/dev/null | sed 's/^v//')
    [ -n "$node_ver" ] && lang_parts="${lang_parts} ${CYAN}node:${node_ver}${RESET}"
  fi

  # Python
  if [ -f "$cwd_raw/pyproject.toml" ] || [ -f "$cwd_raw/setup.py" ] || [ -f "$cwd_raw/requirements.txt" ] || [ -f "$cwd_raw/Pipfile" ]; then
    py_ver=$(python3 --version 2>/dev/null | awk '{print $2}')
    venv=""
    [ -n "$VIRTUAL_ENV" ] && venv=" ($(basename "$VIRTUAL_ENV"))"
    [ -n "$py_ver" ] && lang_parts="${lang_parts} ${CYAN} ${py_ver}${venv}${RESET}"
  fi

  # Rust
  if [ -f "$cwd_raw/Cargo.toml" ]; then
    rs_ver=$(rustc --version 2>/dev/null | awk '{print $2}')
    [ -n "$rs_ver" ] && lang_parts="${lang_parts} ${CYAN} ${rs_ver}${RESET}"
  fi

  # Go
  if [ -f "$cwd_raw/go.mod" ]; then
    go_ver=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
    [ -n "$go_ver" ] && lang_parts="${lang_parts} ${CYAN} ${go_ver}${RESET}"
  fi

  if [ -n "$lang_parts" ]; then
    printf "${SEP}%b" "$lang_parts"
  fi
fi

# --- Section 5: docker context (skip default) ---
docker_ctx=$(docker context show 2>/dev/null)
if [ -n "$docker_ctx" ] && [ "$docker_ctx" != "default" ]; then
  printf "${SEP}${CYAN} %s${RESET}" "$docker_ctx"
fi

# --- Section 6: ProtonVPN (reuse cache file, same as starship) ---
proton_cache="$HOME/.cache/Proton/VPN/connection/connection_persistence.json"
if [ -f "$proton_cache" ]; then
  proton_city=$(python3 -c "
import json, os
conn_file = os.path.expanduser('~/.cache/Proton/VPN/connection/connection_persistence.json')
srv_file = os.path.expanduser('~/.cache/Proton/VPN/serverlist.json')
try:
  with open(conn_file) as f: conn = json.load(f)
  with open(srv_file) as f: sl = json.load(f)
  servers = {s['Name']: s for s in sl.get('LogicalServers', [])}
  sv = servers.get(conn['server']['server_name'], {})
  print(sv.get('City', '') or sv.get('ExitCountry', ''))
except: pass
" 2>/dev/null)
  [ -n "$proton_city" ] && printf "${SEP}${MAGENTA}󰦝 %s${RESET}" "$proton_city"
fi

# --- Section 7: model name ---
if [ -n "$model" ]; then
  printf "${SEP}${MAGENTA}%s${RESET}" "$model"
fi

# --- Section 8: context window usage ---
if [ -n "$used_pct" ]; then
  if awk "BEGIN{exit !($used_pct >= 80)}"; then
    ctx_color="$RED"
  elif awk "BEGIN{exit !($used_pct >= 50)}"; then
    ctx_color="$YELLOW"
  else
    ctx_color="$CYAN"
  fi
  token_str=""
  if [ -n "$ctx_window_size" ]; then
    total_k=$(awk "BEGIN{printf \"%.0f\", $ctx_window_size / 1000}")
    if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" -gt 0 ] 2>/dev/null; then
      used_k=$(awk "BEGIN{printf \"%.0f\", $ctx_tokens / 1000}")
    else
      used_k=$(awk "BEGIN{printf \"%.0f\", ($used_pct / 100) * $ctx_window_size / 1000}")
    fi
    token_str=" ${DIM}${used_k}k/${total_k}k${RESET}"
  fi
  printf "${SEP}${ctx_color}ctx:%.0f%%${RESET}%b" "$used_pct" "$token_str"
fi

# --- Section 9: 5-hour rate limit (only shown at >= 80%) ---
if [ -n "$five_hour_pct" ] && awk "BEGIN{exit !($five_hour_pct >= 80)}"; then
  reset_str=""
  if [ -n "$five_hour_resets" ]; then
    now=$(date +%s)
    secs_left=$(( five_hour_resets - now ))
    if [ "$secs_left" -gt 0 ]; then
      hrs=$(( secs_left / 3600 ))
      mins=$(( (secs_left % 3600) / 60 ))
      if [ "$hrs" -gt 0 ]; then
        reset_str=" (resets ${hrs}h${mins}m)"
      else
        reset_str=" (resets ${mins}m)"
      fi
    fi
  fi
  printf "${SEP}${RED}limit:%.0f%%%s${RESET}" "$five_hour_pct" "$reset_str"
fi
