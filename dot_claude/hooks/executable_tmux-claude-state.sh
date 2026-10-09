#!/usr/bin/env bash
# Sets tmux pane option @claude_state, read by the tmux status bar.
#   input = blocked on you (permission prompt, question, MCP form)
#   done  = finished its turn and nothing in the background will wake it
#   (unset) = working, waiting on background work, or fresh
[ -n "$TMUX_PANE" ] || exit 0
case "$1" in
  input) tmux set -p -t "$TMUX_PANE" @claude_state input ;;
  done)
    if jq -e '((.background_tasks // []) + (.session_crons // [])) | length == 0' >/dev/null; then
      tmux set -p -t "$TMUX_PANE" @claude_state done
    else
      tmux set -pu -t "$TMUX_PANE" @claude_state
    fi ;;
  *) tmux set -pu -t "$TMUX_PANE" @claude_state ;;
esac 2>/dev/null
exit 0
