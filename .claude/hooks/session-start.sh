#!/usr/bin/env bash
# SessionStart: print brief repo context; stdout is added to Claude's context.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}"
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'n/a')"
echo "Uncommitted files: $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
echo "Agents: $(ls .claude/agents 2>/dev/null | sed 's/\.md$//' | paste -sd, -)"
echo "Commands: $(ls .claude/commands 2>/dev/null | sed 's/\.md$//;s/^/\//' | paste -sd, -)"
