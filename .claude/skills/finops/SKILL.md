---
name: finops
description: FinOps review for GitHub and Google Cloud. Reads the implementation, GitHub Actions workflows and cloud setup to find paid resources that are unnecessary or oversized (CI minutes, artifacts, idle or over-provisioned GCP services, chatty Firestore reads, log volume) and produces a ranked, evidence-based savings report. Use for cost reviews, bill spikes, or before adding CI or cloud resources.
---

# FinOps: GitHub and Google Cloud

Find spend that buys nothing, without hurting reliability. Read-only: you analyze and
recommend; you change nothing and never touch cloud resources.

## Principles
- **Measure first.** A saving needs evidence: run history, usage, a metric, a billing line, or
  code you can point at. No evidence, no finding.
- **Never quote prices or quotas from memory.** They change. Cite the current billing docs or the
  user's billing data, or say the number is unknown and name where to find it.
- **Resilience before savings.** Never recommend a cut that risks calls, customers or the
  required PR checks (for example `min-instances: 0` on a latency-critical service, path filters
  on a required status check, dropping a redundant node). If a saving has a risk, state it.
- **Biggest first.** Rank by estimated saving, then effort, then risk. Ignore rounding errors.
- **Say what you could not see** (no billing access, no `gcloud` auth, private repo data).

## Procedure
1. **Scope.** What repo(s) and GCP project(s)? What is the question: general review or a spike?
   Ask if it is unclear. Read `CLAUDE.md` and how the thing is deployed.
2. **Data you can get read-only.**
   - Workflows: `python3 -I .claude/skills/finops/scripts/audit_workflows.py .github/workflows/*.yml`
   - Run history and cost drivers: [references/github-actions.md](references/github-actions.md)
     (`gh run list`, workflow timing, cache and artifact usage).
   - Cloud: [references/gcp.md](references/gcp.md) (read-only `gcloud` listings, billing export,
     recommender). Use only if `gcloud` is authenticated; otherwise ask the user for exports.
3. **Audit the implementation** for code that causes billable usage: unbounded or repeated
   queries, listeners on large collections, polling, retry loops without backoff, debug logging in
   production, large images, duplicated cron or webhook work. Details in the GCP reference.
4. **Audit the workflows** with the script and the GitHub checklist. Judge each finding: the script
   is static and cannot know which jobs are required checks or what runs are really frequent.
5. **Report** (format below). Do not implement; each accepted finding becomes an issue via
   `create-linear-issue`, and the `implementer` does the change.

## Report format
```
FinOps review: <scope>, <date>. Data used: <runs, billing export, none>.
Total identified: <range or "unknown">, <n> findings.

| # | Finding | Evidence | Est. saving | Effort | Risk | Fix |
|---|---|---|---|---|---|---|

Not changed because of risk: <items and why>
Could not verify: <items>
```
Estimates are ranges with their assumptions written out (runs per month x minutes, reads per
request x requests). Mark any number you could not source as `unknown`.

## Never
- Recommend removing redundancy, health checks, backups, or required checks to save money.
- Run anything that creates, modifies or deletes cloud or GitHub resources.
- Report a saving without evidence, or a price you did not source.
- Print secrets or account identifiers found while looking.
