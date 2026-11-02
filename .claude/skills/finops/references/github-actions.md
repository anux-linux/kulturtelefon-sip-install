# GitHub Actions and GitHub cost checklist

Billing is per job-minute, each job rounded **up** to the next minute, with per-OS multipliers
and extra cost for larger runners (check the current billing docs for the values). Public repos
use standard runners for free; private repos draw from the plan's included minutes first.

## Data (read-only)
```bash
gh run list --limit 200 --json workflowName,event,conclusion,createdAt,updatedAt,headBranch
gh api repos/{owner}/{repo}/actions/workflows                       # ids
gh api repos/{owner}/{repo}/actions/workflows/{id}/timing           # may be unavailable on newer billing
gh api repos/{owner}/{repo}/actions/cache/usage                     # cache storage
gh api repos/{owner}/{repo}/actions/artifacts --paginate --jq '.artifacts[] | [.name,.size_in_bytes,.created_at]|@tsv'
```
Billing totals: Settings → Billing → Usage in the web UI; the API route depends on the account's
billing platform, so ask the user for an export if `gh api` is denied.
Compute: runs per month x average job minutes (rounded up per job) x runner type.

## Findings to look for
| Waste | Signal | Fix | Careful |
|---|---|---|---|
| No job timeout | `timeout-minutes` missing (default is 360) | set a realistic limit per job | stuck jobs are the expensive ones |
| Duplicate runs | `on: push` and `on: pull_request` without branch filter | `push` only on `main`; PRs via `pull_request` | |
| Stale runs on new push | no `concurrency` on PR workflows | `concurrency: {group: ..., cancel-in-progress: true}` | never cancel deploy or release jobs |
| Runs for irrelevant changes | no `paths`/`paths-ignore` | filter docs-only changes | **a required status check skipped by path filter stays pending forever**: use an always-running gate job or `paths-ignore` on non-required workflows only |
| No dependency cache | `setup-node/python/java` without `cache`, repeated installs | enable the built-in cache; buildx `cache-from/to: type=gha` for images | cache storage is limited and evicted |
| Expensive jobs run before cheap ones | tests start while lint fails | `needs:` lint/typecheck first | more wall-clock, fewer wasted minutes |
| Many tiny jobs | dozens of 20-second jobs | merge them: each job pays a minute minimum plus setup | sharding tests saves wall-clock, **not** money |
| Wrong runner | macOS/Windows/larger runners where Linux works | use `ubuntu-latest` | only if the code truly needs the OS |
| Full-history checkout | `fetch-depth: 0` | default depth, unless the job needs history | |
| Artifacts kept 90 days | `upload-artifact` without `retention-days`; huge uploads, `node_modules` uploaded | short retention, upload only what is needed | |
| Frequent schedules | cron more than daily, runs on forks | reduce frequency; guard with `if: github.repository == ...` | |
| Draft PRs run everything | no draft guard | `if: github.event.pull_request.draft == false` on expensive jobs | |
| LLM review jobs per push | `claude-code-action` or similar on every `synchronize` | run on `ready_for_review`/label, cancel superseded runs, cap with concurrency | API tokens are billed per run, in addition to minutes |
| Bot PR floods | Dependabot opens many PRs, each runs CI | group updates, weekly schedule | |
| Registry and release storage | old container images, packages, releases | retention/cleanup policy | |
| Seats and features | unused paid seats or add-ons | review in billing, ask the owner | not visible from the repo |

## Judging a finding
- Frequency matters more than size: a 2-minute job on every push beats a 30-minute nightly job.
- Check the run history before claiming "frequent": count real runs.
- Recommend the change with the smallest blast radius first (timeouts, concurrency, retention, cache).
