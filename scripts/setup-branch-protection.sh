#!/usr/bin/env bash
# Require the Claude review checks on a branch, and block merging while review threads are open.
#
# Usage: setup-branch-protection.sh [branch]            dry run: show current state and the new rules
#        setup-branch-protection.sh [branch] --apply    change the GitHub settings
#
# WARNING: --apply REPLACES the branch's whole classic protection (PUT). Compare with the
# "current" output first. Needs admin rights; private repos on a free plan have no branch
# protection (use a ruleset or upgrade).
set -euo pipefail

branch=""; apply=0
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) branch="$a" ;;
  esac
done

repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
[ -n "$branch" ] || branch=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)

# CODE_OWNER_REVIEWS=true also requires CODEOWNERS approval for high-risk paths. Only turn it on
# when a second person exists: an author cannot approve their own PR, so a solo owner would be locked out.
payload=$(jq -n --argjson co "${CODE_OWNER_REVIEWS:-false}" '{
  required_status_checks: { strict: true, contexts: ["code-review", "security-review"] },
  enforce_admins: true,
  required_pull_request_reviews: { required_approving_review_count: 1, dismiss_stale_reviews: true, require_code_owner_reviews: $co },
  restrictions: null,
  required_conversation_resolution: true
}')

echo "Repository: $repo   Branch: $branch"
echo "--- current classic protection:"
gh api "repos/$repo/branches/$branch/protection" 2>&1 | jq '.' 2>/dev/null || echo "(none, or not readable)"
echo "--- new rules:"
echo "$payload" | jq '.'

if [ "$apply" -ne 1 ]; then
  echo "Dry run only. Re-run with --apply to change GitHub."
  exit 0
fi

gh api -X PUT "repos/$repo/branches/$branch/protection" --input - <<<"$payload" >/dev/null
echo "Applied. Merging into '$branch' now needs: code-review, security-review, 1 approval, all conversations resolved."
