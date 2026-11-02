#!/usr/bin/env bash
# UserPromptSubmit: when the prompt mentions Linear issue keys (e.g. ABC-123), add what git
# knows about them (commits, merged, tags) to Claude's context. stdout becomes context.
# Read-only, no network. Set LINEAR_TEAM_KEYS="KUL|AIS" to avoid false positives.
set -euo pipefail

input=$(cat)
prompt=$(jq -r '.prompt // empty' <<<"$input")
dir=$(jq -r '.cwd // empty' <<<"$input")
[ -z "$prompt" ] && exit 0

if [ -n "${LINEAR_TEAM_KEYS:-}" ]; then
  pattern="(${LINEAR_TEAM_KEYS})-[0-9]+"
else
  pattern=${LINEAR_KEY_PATTERN:-'[A-Za-z][A-Za-z0-9]{1,9}-[0-9]+'}
fi
noise='^(UTF|SHA|ISO|AES|RFC|HTTP|TLS|MD|CVE|GPT|X|WCAG|ES|PEP|APACHE|GPL|LGPL|BSD|MIT|PYTHON|NODE|GPT|CLAUDE|OPUS|SONNET|HAIKU|IPV|TLSV|SSL)-'

mapfile -t keys < <(grep -oiE "(^|[^A-Za-z0-9])${pattern}" <<<"$prompt" | grep -oiE "$pattern" \
  | tr '[:lower:]' '[:upper:]' | grep -vE "$noise" | awk '!seen[$0]++' | head -n 5 || true)
[ "${#keys[@]}" -eq 0 ] && exit 0

cd "${dir:-${CLAUDE_PROJECT_DIR:-.}}"
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

script="$(cd "$(dirname "$0")/../.." && pwd)/scripts/linear-git-status.sh"
echo "Git evidence for Linear issues mentioned in the prompt (read-only; merged or tagged does not mean deployed):"
"$script" "${keys[@]}" || true
exit 0
