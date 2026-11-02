#!/usr/bin/env bash
# PreToolUse (Bash): before `gh pr merge`, check locally what branch protection would check.
# Use when GitHub cannot enforce it (free private repos). Blocks (exit 2) unless:
#   - the PR is not a draft and is open
#   - the code-review and security-review checks have SUCCEEDED on the latest commit
#   - no review thread is unresolved (open findings)
# Also blocks --admin (bypasses protection) and --auto (merges later, unchecked).
# Read-only. This guards merges made through Claude only; it cannot stop a merge clicked on github.com.
#
# Environment: PR_CHECKS_SKIP=1 disables the hook (set by the user, not in the command).
set -euo pipefail

[ "${PR_CHECKS_SKIP:-0}" = "1" ] && exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
merge_re='(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)'
[[ "$cmd" =~ $merge_re ]] || exit 0

dir=$(jq -r '.cwd // empty' <<<"$input")
cd "${dir:-${CLAUDE_PROJECT_DIR:-.}}"

block() { { echo "Blocked by require-merge-checks.sh:"; printf ' - %s\n' "$@"; } >&2; exit 2; }

# Arguments after `gh pr merge`
rest=${cmd#*gh pr merge}
read -ra toks <<<"$rest"
target=""; skip=0
for t in "${toks[@]:-}"; do
  if [ "$skip" -eq 1 ]; then skip=0; continue; fi
  case "$t" in
    --admin|--admin=*) block "--admin bypasses the required checks. Ask the user; do not use it." ;;
    --auto|--auto=*)   block "--auto merges later without this check. Merge manually once the checks pass." ;;
    --subject|-t|--body|-b|--body-file|-F|--match-head-commit|-R|--repo) skip=1 ;;
    -*) ;;
    *) [ -n "$target" ] || target="$t" ;;
  esac
done

command -v gh >/dev/null || block "gh is not installed, so the PR cannot be verified."
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || block "Cannot determine the GitHub repository."

pr=$(gh pr view ${target:+"$target"} --json number,state,isDraft,statusCheckRollup,url,files,body,reviews,headRefOid,baseRefName 2>/dev/null) \
  || block "Cannot read the PR${target:+ '$target'} (not found, or gh not authenticated)."

problems=()
[ "$(jq -r '.state' <<<"$pr")" = "OPEN" ] || problems+=("PR is not open.")
[ "$(jq -r '.isDraft' <<<"$pr")" = "false" ] || problems+=("PR is a draft.")

for c in code-review security-review; do
  states=$(jq -r --arg c "$c" '
    [.statusCheckRollup[]? | select((.name // .context) == $c)
     | if .__typename == "CheckRun" then (if .status != "COMPLETED" then "PENDING" else .conclusion end) else .state end]
    | if length == 0 then "MISSING" else (unique | join(",")) end' <<<"$pr")
  case "$states" in
    SUCCESS) ;;
    MISSING) problems+=("Check '$c' has not run on the latest commit.") ;;
    *PENDING*|*EXPECTED*) problems+=("Check '$c' is still running ($states). Wait for it.") ;;
    *) problems+=("Check '$c' is not green ($states).") ;;
  esac
done

number=$(jq -r '.number' <<<"$pr")
threads=$(gh api graphql -F n="$number" -f o="${repo%%/*}" -f r="${repo##*/}" -f query='
  query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
    reviewThreads(first:100){pageInfo{hasNextPage} nodes{isResolved}}}}}' 2>/dev/null) \
  || { problems+=("Cannot read review threads, so open findings cannot be ruled out."); threads=""; }
if [ -n "$threads" ]; then
  [ "$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"$threads")" = "false" ] \
    || problems+=("More than 100 review threads; cannot verify they are all resolved.")
  open=$(jq -r '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length' <<<"$threads")
  [ "$open" = "0" ] || problems+=("$open review thread(s) unresolved. Fix or answer each finding and resolve it.")
fi

# Risk tier: the change sets the tier, not the author. The map comes from the base branch
# when possible, so a PR cannot lower its own tier by editing the map.
rank() { case "$1" in low) echo 1 ;; medium) echo 2 ;; high) echo 3 ;; *) echo 0 ;; esac; }
base=$(jq -r '.baseRefName' <<<"$pr")
map=$(mktemp); trap 'rm -f "$map"' EXIT
if ! git show "origin/$base:.github/risk-tiers.conf" >"$map" 2>/dev/null; then
  root=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
  cp "$root/.github/risk-tiers.conf" "$map" 2>/dev/null || : >"$map"
fi
computed=""; why=""
if [ ! -s "$map" ]; then
  problems+=("No .github/risk-tiers.conf found, so the risk tier cannot be computed.")
else
  out=$(jq -r '.files[]?.path' <<<"$pr" | "$(dirname "$0")/../../scripts/risk-tier.sh" --map "$map" --stdin) \
    || problems+=("Risk tier computation failed (see scripts/risk-tier.sh).")
  computed=$(head -n1 <<<"$out"); why=$(tail -n +2 <<<"$out")
fi

if [ -n "$computed" ]; then
  declared=$(jq -r '.body // ""' <<<"$pr" | grep -oiE '^[[:space:]]*- \[[xX]\] \*\*(Low|Medium|High)\*\*' \
    | grep -oiE 'Low|Medium|High' | tr '[:upper:]' '[:lower:]' || true)
  n=$(grep -c . <<<"$declared" || true)
  if [ "$n" -eq 0 ]; then
    problems+=("No risk tier is ticked in the PR description (computed tier: $computed).")
  elif [ "$n" -gt 1 ]; then
    problems+=("More than one risk tier is ticked in the PR description. Tick exactly one.")
  elif [ "$(rank "$declared")" -lt "$(rank "$computed")" ]; then
    problems+=("PR declares risk '$declared' but its files make it '$computed'. Correct the PR description. Files setting the tier:" "$why")
  fi
fi

# Approvals go stale on a new commit: if the PR has any, one must be on the latest commit.
head_sha=$(jq -r '.headRefOid' <<<"$pr")
approvals=$(jq '[.reviews[]? | select(.state=="APPROVED")] | length' <<<"$pr")
current=$(jq --arg h "$head_sha" '[.reviews[]? | select(.state=="APPROVED" and .commit.oid==$h)] | length' <<<"$pr")
if [ "$approvals" -gt 0 ] && [ "$current" -eq 0 ]; then
  problems+=("All approvals are on older commits; the PR changed since. Ask for a new approval.")
fi

[ "${#problems[@]}" -eq 0 ] || block "${problems[@]}" "Fix these, push, wait for the checks, then retry. A person approves the PR; never merge on the agent's say-so."

# High risk: a person must approve. Force the confirmation prompt and say why.
if [ "$computed" = "high" ]; then
  jq -n --arg r "HIGH RISK change, a person must approve. Files setting the tier:"$'\n'"$why" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
fi
exit 0
