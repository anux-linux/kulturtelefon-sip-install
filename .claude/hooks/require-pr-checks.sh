#!/usr/bin/env bash
# PreToolUse (Bash): before `gh pr create`, make sure the PR checks exist:
#   1. .github/workflows/claude-review.yml runs /code-review --comment and the security review
#   2. branch protection on the base branch requires the code-review and security-review
#      checks and requires all conversations to be resolved
# Exit 2 blocks the PR and tells Claude what is missing. Read-only: it never changes GitHub.
#
# Environment: PR_CHECKS_SKIP=1 disables the hook (set by the user, not in the command).
set -euo pipefail

[ "${PR_CHECKS_SKIP:-0}" = "1" ] && exit 0

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
create_re='(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'
[[ "$cmd" =~ $create_re ]] || exit 0

dir=$(jq -r '.cwd // empty' <<<"$input")
cd "${dir:-${CLAUDE_PROJECT_DIR:-.}}"
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

required_checks=(code-review security-review)
problems=()

# 1. The workflow
wf="$root/.github/workflows/claude-review.yml"
if [ ! -f "$wf" ]; then
  problems+=("Missing .github/workflows/claude-review.yml (the PR check workflow).")
else
  grep -qE '^[[:space:]]*pull_request:' "$wf" || problems+=("Workflow does not trigger on pull_request.")
  for job in "${required_checks[@]}"; do
    grep -qE "^  ${job}:" "$wf" || problems+=("Workflow has no '${job}' job.")
  done
  grep -q 'anthropics/claude-code-action@' "$wf" || problems+=("Workflow does not use anthropics/claude-code-action.")
  grep -qE 'code-review.*--comment' "$wf" || problems+=("Workflow does not run /code-review with --comment.")
  grep -q 'secrets.CLAUDE_CODE_OAUTH_TOKEN' "$wf" || problems+=("Workflow does not use the CLAUDE_CODE_OAUTH_TOKEN secret.")
  grep -q 'structured_output' "$wf" || problems+=("Workflow does not gate the security review on its structured output.")
fi

# 2. Branch protection on the base branch
if ! command -v gh >/dev/null; then
  problems+=("gh is not installed, so branch protection cannot be verified.")
elif ! repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || [ -z "$repo" ]; then
  problems+=("Cannot determine the GitHub repository (gh not authenticated or no GitHub remote).")
else
  base=""
  base_re='(--base[[:space:]=]+|-B[[:space:]]+)([^[:space:]]+)'
  [[ "$cmd" =~ $base_re ]] && base="${BASH_REMATCH[2]}"
  [ -n "$base" ] || base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)

  if [ -z "$base" ]; then
    problems+=("Cannot determine the base branch.")
  else
    # Classic branch protection and rulesets can both provide the rules.
    err=$(mktemp); trap 'rm -f "$err"' EXIT
    classic=$(gh api "repos/$repo/branches/$base/protection" 2>"$err" || true)
    unenforceable=0
    if grep -q 'Upgrade to GitHub' <<<"$classic" || grep -q 'Upgrade to GitHub' "$err"; then
      unenforceable=1   # free private repo: GitHub offers no branch protection
    fi
    [ "$unenforceable" -eq 0 ] && [ -n "$classic" ] || classic='{}'
    rules=$(gh api "repos/$repo/rules/branches/$base" 2>/dev/null || echo '[]')
    jq -e 'type=="array"' <<<"$rules" >/dev/null 2>&1 || rules='[]'

    contexts=$( {
      jq -r '[(.required_status_checks.contexts // [])[], (.required_status_checks.checks // [])[].context] | .[]' <<<"$classic" 2>/dev/null || true
      jq -r '[.[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context] | .[]' <<<"$rules" 2>/dev/null || true
    } | sort -u)

    threads=$( {
      jq -r '.required_conversation_resolution.enabled // false' <<<"$classic" 2>/dev/null || true
      jq -r '[.[] | select(.type=="pull_request") | .parameters.required_review_thread_resolution] | any' <<<"$rules" 2>/dev/null || true
    } | grep -c '^true$' || true)

    if [ "$unenforceable" -eq 1 ]; then
      echo "require-pr-checks: GitHub cannot enforce branch protection on this repo (free private plan). Merges are guarded locally by require-merge-checks.sh instead." >&2
    else
      for c in "${required_checks[@]}"; do
        grep -qx "$c" <<<"$contexts" || problems+=("Branch protection on '$base' does not require the '$c' status check.")
      done
      [ "$threads" -ge 1 ] || problems+=("Branch protection on '$base' does not require all conversations to be resolved, so open findings would not block the merge.")
    fi
  fi
fi

[ "${#problems[@]}" -eq 0 ] && exit 0

{
  echo "Blocked by require-pr-checks.sh: the PR checks are not in place."
  printf ' - %s\n' "${problems[@]}"
  echo
  echo "Fix: add/restore .github/workflows/claude-review.yml and the CLAUDE_CODE_OAUTH_TOKEN repository secret."
  echo "Branch protection changes GitHub settings: show the user './scripts/setup-branch-protection.sh' (dry run) and"
  echo "only apply it with '--apply' after the user approves. Then retry 'gh pr create'."
} >&2
exit 2
