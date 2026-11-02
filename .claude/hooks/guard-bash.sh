#!/usr/bin/env bash
# PreToolUse (Bash): block obviously destructive commands.
# Input: hook JSON on stdin. Exit 2 = block, message on stderr is shown to Claude.
set -euo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

patterns=(
  'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f?[[:space:]]+(/|~|\$HOME)([[:space:]]|$)'
  'git[[:space:]]+push[[:space:]].*(--force|-f)([[:space:]]|$)'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh'
  'chmod[[:space:]]+-R[[:space:]]+777'
)

for p in "${patterns[@]}"; do
  if [[ "$cmd" =~ $p ]]; then
    echo "Blocked by guard-bash.sh: command matches destructive pattern '$p'. Ask the user before running it." >&2
    exit 2
  fi
done
exit 0
