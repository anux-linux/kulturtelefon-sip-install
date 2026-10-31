#!/usr/bin/env bash
# Report what git knows about Linear issues: commits and branches that mention an issue key,
# whether they are merged into the default branch, and the first tag containing them.
#
# Usage:
#   linear-git-status.sh                 list every issue key found in history
#   linear-git-status.sh ABC-12 ABC-15   details for these issues
#   linear-git-status.sh --jobs ABC-12   also show CI runs per merged commit (needs gh + network)
#
# Environment:
#   LINEAR_TEAM_KEYS     e.g. "KUL|AIS": only these team keys count (strongly recommended)
#   LINEAR_KEY_PATTERN   ERE for a key when LINEAR_TEAM_KEYS is unset (default: generic, noise filtered)
#
# Read-only. Git can show committed / merged / tagged. It cannot prove "deployed":
# use --jobs and the project's deploy records for that.
set -euo pipefail

jobs=0
keys=()
for a in "$@"; do
  case "$a" in
    --jobs) jobs=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) keys+=("$(tr '[:lower:]' '[:upper:]' <<<"$a")") ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository" >&2; exit 1; }

if [ -n "${LINEAR_TEAM_KEYS:-}" ]; then
  pattern="(${LINEAR_TEAM_KEYS})-[0-9]+"
else
  pattern=${LINEAR_KEY_PATTERN:-'[A-Za-z][A-Za-z0-9]{1,9}-[0-9]+'}
fi
noise='^(UTF|SHA|ISO|AES|RFC|HTTP|TLS|MD|CVE|GPT|X|WCAG|ES|PEP)-'

# Default branch: origin/HEAD, else main, else master.
base=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
if [ -z "$base" ]; then
  for c in main master; do
    git rev-parse -q --verify "refs/heads/$c" >/dev/null && { base=$c; break; }
  done
fi
[ -n "$base" ] || { echo "cannot determine default branch" >&2; exit 1; }

key_re() { printf '(^|[^A-Za-z0-9])%s([^0-9]|$)' "$1"; }

if [ "${#keys[@]}" -eq 0 ]; then
  refs=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes)
  found=$( { git log --all --format='%s%n%b'; printf '%s\n' "$refs"; } \
    | grep -oiE "(^|[^A-Za-z0-9])${pattern}" | grep -oiE "${pattern}" \
    | tr '[:lower:]' '[:upper:]' | grep -vE "$noise" | sort | uniq -c | sort -rn || true)
  if [ -z "$found" ]; then echo "No Linear issue keys found in history (base: $base)."; exit 0; fi
  echo "Linear issue keys in history (base: $base):"
  echo "$found" | awk '{printf "  %-12s %s mention(s)\n", $2, $1}'
  exit 0
fi

for key in "${keys[@]}"; do
  echo "== $key (base: $base)"
  mapfile -t shas < <(git log --all --regexp-ignore-case --extended-regexp \
    --grep="$(key_re "$key")" --format=%H)
  branches=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes \
    | grep -iE "$(key_re "$key")" || true)

  if [ "${#shas[@]}" -eq 0 ]; then
    echo "  commits: none"
    [ -n "$branches" ] && echo "  branches: $(paste -sd' ' <<<"$branches")"
    echo "  status: ${branches:+branch only, no commits}${branches:-not found in git}"
    continue
  fi

  merged=0; first_tag=""
  for sha in "${shas[@]}"; do
    state="not merged"
    if git merge-base --is-ancestor "$sha" "$base" 2>/dev/null; then
      state="merged"; merged=$((merged + 1))
      t=$(git tag --contains "$sha" --sort=creatordate 2>/dev/null | head -n1 || true)
      [ -n "$t" ] && first_tag=${first_tag:-$t}
    fi
    printf '  %s %s %-10s %s\n' "$(git log -1 --format=%h "$sha")" \
      "$(git log -1 --format=%ad --date=short "$sha")" "[$state]" \
      "$(git log -1 --format=%s "$sha" | cut -c1-70)"
    if [ "$jobs" -eq 1 ] && [ "$state" = merged ] && command -v gh >/dev/null; then
      gh run list --commit "$sha" --limit 5 --json workflowName,conclusion,status \
        --jq '.[] | "      job: \(.workflowName) -> \(.conclusion // .status)"' 2>/dev/null || true
    fi
  done
  [ -n "$branches" ] && echo "  branches: $(paste -sd' ' <<<"$branches")"

  if [ "$merged" -eq 0 ]; then summary="in branches only, not merged"
  elif [ "$merged" -lt "${#shas[@]}" ]; then summary="partly merged ($merged of ${#shas[@]} commits)"
  else summary="merged"; fi
  [ -n "$first_tag" ] && summary="$summary, first release tag: $first_tag"
  echo "  status: $summary (git cannot prove deployment)"
done
