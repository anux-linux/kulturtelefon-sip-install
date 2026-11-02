---
description: Red team vs blue team debate on a plan, diff/PR, document or proposal; the mediator decides what must change
argument-hint: <plan path | PR | diff | doc path | Linear key | proposal text> [rounds 1|2]
---

Run a red-team / blue-team debate on: $ARGUMENTS

You orchestrate; you do not attack, defend or judge yourself. Run from the main session, since
subagents cannot launch other subagents. This runs only because I asked: never start it on your own.

## 1. Resolve the target
- Plan or document: the file path. Implementation: the PR number (`gh pr diff`), a branch, or the
  working-tree `git diff`. Linear key: read the issue. Otherwise the text I gave is an inline proposal.
- Type it as `plan`, `implementation`, `document` or `feature`. If the target is missing or the
  type is unclear, ask me.
- Rounds: the number I gave, otherwise 1 (never more than 2).
- Slug: a short kebab-case name; date: `date +%F`. Record path: `docs/debates/<date>-<slug>.md`.

## 2. Red team
Launch `red-team`. The brief is self-contained: the artifact (path and range, or the full text if
inline), its type, and "read `.claude/skills/red-blue-debate/SKILL.md` and `references/lenses.md`".

## 3. Blue team
Launch `blue-team` with the artifact and the red team's attacks, **verbatim and complete**.

## 4. Round 2 (only if asked for rounds 2)
List the attacks the blue team answered REFUTE. Launch `red-team` for a rebuttal on only those
ids, then `blue-team` once more with the rebuttal. Skip this step if nothing was contested.

## 5. Mediator
Launch `mediator` with the artifact, all red output and all blue output, verbatim.

## 6. Record and report
- Write the record to the path above, following
  `.claude/skills/red-blue-debate/templates/debate-record.md`: mediator decision first, then the
  red and blue outputs verbatim.
- Tell me: the verdict, the three-sentence reasoning, the ranked findings (top 5), the required
  changes, the human decisions, and the record path. Say what the agents could not verify.

## Rules
- Do not change the artifact and do not apply the required changes. Offer the next step: update
  the plan (planner), create issues (`create-linear-issue`), or fix the code (implementer).
- If the target is a plan or PR, offer to add a `Debate: <record path>` line to it; do it only
  if I agree.
- Never edit, shorten or reword an agent's output when passing it on or recording it.
- The verdict is advice: a person decides on `REJECT`, security and cost trade-offs.
