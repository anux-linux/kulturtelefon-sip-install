#!/usr/bin/env bash
# Sanity-check the harness: valid JSON, executable hooks, frontmatter present.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

jq empty .claude/settings.json || err ".claude/settings.json is not valid JSON"

for h in .claude/hooks/*.sh; do
  [ -x "$h" ] || err "$h is not executable"
  bash -n "$h" || err "$h has syntax errors"
done

for f in .claude/agents/*.md .claude/commands/*.md .claude/skills/*/SKILL.md; do
  [ "$(head -n1 "$f")" = "---" ] || err "$f is missing YAML frontmatter"
  grep -q '^description:' "$f" || err "$f is missing a description"
done

for f in .claude/agents/*.md; do
  grep -q '^name:' "$f" || err "$f is missing a name"
done

# Agents that pin a model must use a known alias or a claude-* id.
for f in .claude/agents/*.md; do
  m=$(sed -n '2,/^---$/{s/^model:[[:space:]]*//p}' "$f")
  [ -z "$m" ] || [[ "$m" =~ ^(haiku|sonnet|opus|inherit|claude-[a-z0-9-]+)$ ]] || err "$f has unknown model '$m'"
done

# Risk tiers: the map is well-formed and CODEOWNERS covers every high-risk path.
while read -r t p; do
  case "$t" in ''|'#'*) continue ;; esac
  case "$t" in low|medium|high) ;; *) err ".github/risk-tiers.conf: unknown tier '$t'"; continue ;; esac
  [ -n "$p" ] || { err ".github/risk-tiers.conf: tier '$t' has no pattern"; continue; }
  [ "$t" = high ] || continue
  q=${p%\*}
  grep -q "^/${q} " .github/CODEOWNERS || err ".github/CODEOWNERS does not cover high-risk path '$p'"
done < .github/risk-tiers.conf

[ "$fail" -eq 0 ] && echo "OK: harness is valid"
exit "$fail"
