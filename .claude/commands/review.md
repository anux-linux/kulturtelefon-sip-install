---
description: Multi-agent review of the current changes: parallel finders, verifiers vote, ranked report
argument-hint: [branch | PR | extra focus] [round N]
---

Review the current changes. Extra input from me: $ARGUMENTS

You orchestrate; you do not review or fix anything yourself. Run from the main session, since
subagents cannot launch other subagents.

## 1. Scope
- Diff range: the branch or PR named above, otherwise `git diff` plus `git diff --staged`.
  Stop and say so if the diff is empty.
- Round: the number I gave, otherwise 1. Keep a list of findings already reported in this
  conversation as **prior findings**.

## 2. Find (parallel)
In ONE message, launch four `code-reviewer` agents with these focuses. Each brief is
self-contained: diff range, focus, round, prior findings, and "read `CLAUDE.md` and `REVIEW.md`".

| Focus | Looks for |
|---|---|
| correctness | wrong behavior, exit codes, error handling, edge cases, broken contracts between files |
| security | permission widening, injection via unquoted input, guards that fail open, secrets, destructive commands |
| consistency | docs, README, `CLAUDE.md`, plans and agent/skill files that no longer match the change |
| leanness | code the change adds that something already in the repo, the standard library or an installed dependency covers; options, abstractions or dependencies the goal does not need |

## 3. Merge
Combine the four reports. Drop duplicates (same location and cause). Do not add findings of
your own.

## 4. Verify (vote)
For every **Important** finding, launch two `review-verifier` agents in parallel (all findings
at once, in one message), each given only that finding and the diff range.
- Keep a finding only if **both** vote CONFIRMED. REFUTED or UNCERTAIN from either drops it.
- Nits and Pre-existing findings are not voted on. Keep at most 3 nits, and none if any
  Important finding survived.

## 5. Report
Follow `REVIEW.md`. Start with the count: `<n> Important, <n> Nit, <n> Pre-existing`. Then the
surviving findings, most severe first, each with `path:line`, scenario, and fix.
After them, one line: how many candidates were dropped by the vote, and which reviewer found
each surviving finding. If nothing survived, say so in one line and stop.

## Rules
- Do not apply fixes until I confirm.
- Round 3 or later: say that the next round reviews only the diff since this one, and if the
  same area keeps failing, recommend reconsidering the approach instead of another round.
- An agent's verdict is never an approval; a person approves the PR.
