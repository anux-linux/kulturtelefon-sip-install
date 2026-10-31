#!/usr/bin/env bash
# PreToolUse (Edit|Write): refuse edits to secrets and lockfiles.
set -euo pipefail

path=$(jq -r '.tool_input.file_path // empty')
[ -z "$path" ] && exit 0

case "$path" in
  *.env|*.env.*|*/secrets/*|*.pem|*.key|*/package-lock.json|*/pnpm-lock.yaml)
    echo "Blocked by protect-files.sh: '$path' is protected. Ask the user before changing it." >&2
    exit 2
    ;;
esac
exit 0
