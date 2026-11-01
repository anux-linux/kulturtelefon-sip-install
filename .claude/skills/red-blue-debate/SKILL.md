---
name: red-blue-debate
description: Rules for the red-team / blue-team / mediator debate that stress-tests a plan, implementation, document (architecture, deployment, setup) or proposed feature. Defines the finding formats, scoring and verdicts shared by the red-team, blue-team and mediator agents and the /debate command.
---

# Red team vs blue team

Three roles examine one **artifact** (a plan, a diff, a document, or a proposal):

| Role | Job | Output |
|---|---|---|
| red-team | Find everything that could go wrong, and argue why this is a bad idea | numbered attacks `R1...` |
| blue-team | Defend the artifact as far as honesty allows | one answer per attack |
| mediator | Rank the attacks against the defence, decide whether and how the artifact must change | verdict and required changes |

All three are read-only. They never edit the artifact. The `/debate` command runs them and
stores the record in `docs/debates/`.

## Ground rules for everyone
- **Evidence over rhetoric.** A claim needs a source: `path:line`, a quote from the artifact, a
  command result. Something you assume must be written as `assumption: ...`.
- **Attack the artifact, not the author.** Work only from what was given and what the repo shows.
- **Do not invent facts** about systems you have not seen. Say what you could not check.
- Pick the lens set for the artifact type from [references/lenses.md](references/lenses.md).

## Attack format (red-team)
At most 7 per round, most severe first, no padding:
```
R1 [Critical | Major | Minor] <title>
Target: <path, section or quote>
Attack: what goes wrong, and why this is the worst way to do it
Scenario: concrete trigger, then consequence
Impact: 1-5   Likelihood: 1-5
Evidence: <source> or "assumption: ..."
Cheapest fix: <the smallest change that would remove the risk>
```
Impact 5 = data loss, security breach, outage or money loss; 1 = cosmetic. Likelihood 5 = will
happen in normal use; 1 = needs unusual conditions.

## Defence format (blue-team)
Answer **every** attack, in order, with exactly one outcome:
```
R1: REFUTE | MITIGATE | CONCEDE
Reason: evidence for the answer
Change: (MITIGATE only) the concrete edit to the artifact
Residual risk: what remains after the change (or "none")
```
- **REFUTE** only with evidence that the attack cannot happen or does not apply.
- **MITIGATE** only with a concrete, specific change; "we will be careful" is not one.
- **CONCEDE** when the attack is valid and no good defence exists. Defending a valid attack
  with weak arguments counts as a failure of the blue team.

## Ranking and verdict (mediator)
Score each finding `Impact x Likelihood` (1-25), then rule on it after reading the defence:

| Ruling | When | Score used |
|---|---|---|
| DISMISSED | the refutation holds up when you check it yourself | 0 |
| REDUCED | mitigation is real, some risk remains | score of the residual risk |
| UPHELD | conceded, or the defence does not hold | full score |

Verify the decisive claims yourself (read the code, run read-only commands) instead of trusting
either side. Justify every dismissal.

**Verdict** (defaults; explain any deviation):

| Verdict | When |
|---|---|
| `ACCEPT` | no upheld finding above 6 |
| `ACCEPT WITH CHANGES` | upheld or reduced findings above 6, all fixable with local changes |
| `REWORK` | an upheld finding of 15 or more needs a structural change |
| `REJECT` | an upheld finding of 20 or more with no workable mitigation, or the need itself is refuted |

"No change needed" is a legitimate outcome. Do not invent changes to look useful.

Output format is in [templates/debate-record.md](templates/debate-record.md).

## Rounds
Default one round: red, blue, mediator. A second round is optional and covers only the attacks
the blue team contested: red answers those ids, blue replies once. Never more than two rounds.

## Never
- Edit the artifact, create issues or change anything outside the debate record.
- Let the mediator's verdict stand in for a person's decision on `REJECT`, security or cost
  trade-offs: list them under "Human decisions".
