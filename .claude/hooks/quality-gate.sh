#!/usr/bin/env bash
# PreToolUse (Bash): run typecheck, lint and tests before `git commit` in a Node.js project.
# Blocks the commit (exit 2) if any step fails; the tail of the failing output goes to Claude.
#
# Target project, first match wins:
#   $QUALITY_GATE_DIR  ->  "cwd" from the hook JSON  ->  $CLAUDE_PROJECT_DIR  ->  $PWD
#
# Environment:
#   QUALITY_GATE_STEPS    npm scripts to run, in order   (default: "typecheck lint test:run")
#   QUALITY_GATE_TIMEOUT  seconds per step               (default: 600)
#   QUALITY_GATE_SKIP=1   disable the gate
#
# Manual run (no hook JSON):  quality-gate.sh --run [dir]
set -euo pipefail

[ "${QUALITY_GATE_SKIP:-0}" = "1" ] && exit 0

dir=""
if [ "${1:-}" = "--run" ]; then
  dir="${2:-}"
else
  input=$(cat)
  cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
  commit_re='(^|[;&|[:space:]])git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*commit([[:space:]]|$)'
  [[ "$cmd" =~ $commit_re ]] || exit 0
  dir=$(jq -r '.cwd // empty' <<<"$input")
fi
dir="${QUALITY_GATE_DIR:-${dir:-${CLAUDE_PROJECT_DIR:-$PWD}}}"

[ -f "$dir/package.json" ] || exit 0   # not a Node project: nothing to gate
cd "$dir"

if [ ! -d node_modules ]; then
  echo "quality-gate: node_modules missing in $dir. Run 'npm install' first." >&2
  exit 2
fi

steps=${QUALITY_GATE_STEPS:-"typecheck lint test:run"}
limit=${QUALITY_GATE_TIMEOUT:-600}
log=$(mktemp)
trap 'rm -f "$log"' EXIT

for step in $steps; do
  if ! jq -e --arg s "$step" '.scripts[$s] // empty' package.json >/dev/null; then
    echo "quality-gate: no '$step' script in $dir/package.json, skipping" >&2
    continue
  fi
  echo "quality-gate: npm run $step ..." >&2
  if ! CI=1 timeout "$limit" npm run --silent "$step" >"$log" 2>&1; then
    {
      echo "quality-gate: '$step' FAILED in $dir. Fix it before committing. Last output:"
      tail -n 40 "$log"
    } >&2
    exit 2
  fi
done

echo "quality-gate: all checks passed" >&2
exit 0
