#!/usr/bin/env bash
# PreToolUse:Bash hook. Blocks heavy local work on this shared box
# (full test suites, containers, release builds, Qdrant). Exit 2 = block.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null || true)
[[ -z "$cmd" ]] && exit 0

block() {
  echo "BLOCKED by block-heavy-local: $1. Run targeted tests only; verify on CI." >&2
  exit 2
}

shopt -s nocasematch
[[ "$cmd" =~ docker[[:space:]-]+compose[[:space:]].*(up|build) ]] && block "docker compose up/build"
[[ "$cmd" =~ (docker|podman)[[:space:]]+(build|run)[[:space:]] ]] && block "container build/run"
[[ "$cmd" =~ cargo[[:space:]]+(build|test|run)[[:space:]].*--release ]] && block "cargo release build"
[[ "$cmd" =~ qdrant ]] && [[ "$cmd" =~ (docker|podman|run|start) ]] && block "Qdrant"
[[ "$cmd" =~ ^act([[:space:]]|$) ]] && block "local CI runner (act)"

# Full test suites: test runners with no file/path/filter argument.
for runner in 'pytest' 'npm test' 'npm run test' 'pnpm test' 'yarn test' 'mix test' 'cargo test' 'go test ./...' 'vitest run' 'jest'; do
  if [[ "$cmd" =~ (^|[;&|[:space:]])${runner}[[:space:]]*($|[;&|]) ]]; then
    block "full test suite ('$runner' with no target)"
  fi
done
exit 0
