# REVIEW.md

Rules for reviewers of kulturtelefon-sip-install, human and agent. Read `CLAUDE.md` and
`README.md` first. Everything under `src/` runs as root on a FreeSWITCH node that is reachable
from the internet, and this repository is public.

## What failure looks like here

| Area | A bug is... |
|---|---|
| `src/install.sh`, `src/pre-install.sh`, `src/resources/*.sh` | A step that is not safe to run twice, a failed step that does not stop the install, a package source or download without a verified signature or checksum, a credential written to a file others can read. |
| `src/resources/iptables.sh`, `src/resources/fail2ban/` | A rule that opens more than the change needs, a rule or jail that can block the Kamailio nodes, a rule that is lost on reboot. |
| `src/resources/switch/` | The Event Socket reachable beyond `localhost` or left with a default password, a widened ACL, a SIP profile change that breaks calls that arrive through Kamailio. |
| Everything | A credential, token, host list or customer data in the repository. |
| `README.md`, `CLAUDE.md` | It lies: the text no longer matches the scripts, paths, commands or behavior. |

## Evidence

- Every finding names `path:line` and a concrete failing scenario (input or state, then wrong result).
- No evidence, no finding. Do not report what `sh -n`, `scripts/ai-suite-sync.sh --check` or `scripts/validate.sh` already catch.
- Do not report a problem that was already there unless the PR touches it; label it **Pre-existing**.

## Severity labels

- **Important**: wrong behavior, security or safety regression, a guard that can be bypassed, a doc that lies.
- **Nit**: style or wording with no effect on behavior. At most **3 nits** per review; skip them entirely if any Important finding exists.
- **Pre-existing**: real, but not introduced by this PR.

## Skip

The copied ai-suite files that `.claude/ai-suite.lock` lists (review them in ai-suite; here only check that `scripts/ai-suite-sync.sh --check` passes).

## Convergence

- Do not repeat a finding already posted. Flag the class of bug so the author fixes every instance.
- After the third round, review the diff since the last round only, and ask the author to reconsider the approach if the same area keeps failing.
- An agent's approval never counts as a person's.

## Always needs a person

Every path tiered `high` in `.github/risk-tiers.conf`. The tier is computed from the changed files, never taken from the PR description alone. An approval counts only for the commit it was given on.

## Summary format

Start with the count: `2 Important, 1 Nit, 0 Pre-existing`. If there is nothing to fix, say so in one line and stop.
