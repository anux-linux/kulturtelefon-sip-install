---
name: create-linear-issue
description: Create a Linear issue that follows the team rules. Every issue belongs to a project, every project to an initiative, and every issue is exactly one of planning, implementing, review or deployment, with that category's template and done-criteria. Use whenever creating or splitting a Linear issue.
---

# Create a Linear issue

Never create an issue that breaks the hierarchy or the category rules. Ask instead of guessing.

## Hierarchy (hard rules)

`Initiative → Project → Issue`

- Every issue has a **project**. Every project has an **initiative**. No orphans.
- Find them first with the Linear tools (`list_initiatives`, `list_projects`, `list_teams`).
- Project missing: create it with `save_project` under the right initiative.
- Initiative missing or several fit: **ask the user**. Never create an initiative or pick one on a guess.
- Search `list_issues` for a similar open issue first. Reuse or link it instead of duplicating.

## Category (hard rule)

Each issue is exactly one of the following, set as a label with the same name. Use the
existing labels; if one is missing, ask before creating it.

| Category | Describes | Template |
|---|---|---|
| `planning` | A task where planning is required. No implementation, no code. | [templates/planning.md](templates/planning.md) |
| `implementing` | One increment, with everything needed to build and test it. | [templates/implementing.md](templates/implementing.md) |
| `review` | Everything between a finished increment and a verified production release. | [templates/review.md](templates/review.md) |
| `deployment` | All steps to deploy to production. | [templates/deployment.md](templates/deployment.md) |

If a request mixes categories, split it into one issue per category and link them.
Use the template for the category; fill every section, remove none.

## Done criteria (state them in the issue)

| Category | Done when |
|---|---|
| `planning` | A plan exists **and** implementation has started (a linked `implementing` issue is In Progress or beyond). |
| `implementing` | The increment exists, its tests pass, and it is committed. |
| `review` | The PR is merged to `main`, deployed to production, and tested on production. |
| `deployment` | The change is deployed to production and the production checks pass. |

`review` and `deployment` check the code in the PR or in production, so they are not done
when the code is written.

## Links

Set relations when creating, using `save_issue` (`parentId`, `blockedBy`, `relatedTo`):

- `planning` **blocks** its `implementing` and/or `review` issues. A planning issue must be
  linked to at least one of them.
- `implementing` **blocks** the `review` issue and the `deployment` issue of the same change.
- `deployment` is **related to** `review`, not blocked by it: review closes only after the
  production deploy and production test, so a blocking link would deadlock. Production
  deployment starts only after the PR is approved and merged; write that into its preconditions.
- Put the issue key in every commit message and branch name (for example
  `feat: add hello printer KUL-12`) so `scripts/linear-git-status.sh` can find the work.

## Procedure

1. Restate the request in one line. Ask about anything ambiguous (category, project, scope).
2. Resolve team, initiative and project. Check for duplicates.
3. Pick the category. Split if needed.
4. Fill the template. No placeholders left; each section concrete enough that someone who
   has not seen this conversation can act on it.
5. Create the issue with project, label and relations in one `save_issue` call.
6. Read it back (`get_issue`) and confirm project, initiative via project, label, links and
   done criteria are set. Report the issue key and URL, and anything left open.

## Never

- Create an issue without a project or a project without an initiative.
- Put code, or an implementation, into a `planning` issue.
- Leave out the test description of an `implementing` issue.
- Mark an issue done outside its done criteria.
