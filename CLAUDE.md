# CLAUDE.md

Guidance for coding agents working in this repository.

## Project

kulturtelefon-sip-install installs a Kulturtelefon FreeSWITCH node on a fresh Debian host:
`src/pre-install.sh` clones this repository to `/usr/src`, and `src/install.sh` installs
FreeSWITCH from the SignalWire repository with the SIP profiles, Event Socket and
`mod_http_cache` configuration in `src/resources/switch/`, SNMP, the iptables rules, sngrep and
fail2ban. The scripts are POSIX `sh` and run as root on a host that is reachable from the
internet. The repository is public: never commit a credential, a token, a host list or customer
data. Usage, variables and what the installer writes: `README.md`.

## Commands

There is no build and no test suite. The gate before every commit, run from the repository
root:

```bash
scripts/ai-suite-sync.sh --check
scripts/validate.sh
git ls-files -z 'src/*.sh' | xargs -0 -n1 sh -n
```

All three must pass. Do not commit on red. Commit subjects follow Conventional Commits.

## AI harness: ai-suite

<!-- BEGIN ai-suite: identical in the CLAUDE.md of kulturtelefon-website,
kulturtelefon-sip, kulturtelefon-proxy and kulturtelefon-sip-install.
Change all four in the same round. -->

This repository follows the ai-suite harness (anux-linux/ai-suite). Its rules are binding here
and win: where this file, a plan or an issue contradicts ai-suite, ai-suite applies. The rest of
this file adds what ai-suite leaves to the repository and gives way wherever the two differ.

The harness is copied from the ai-suite commit on the first line of `.claude/ai-suite.lock`,
which lists every copied file with its mode and SHA-256 and is byte-identical in all four
repositories: `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`, `.claude/skills/`,
`.claude/settings.json`, `.github/workflows/claude-review.yml`, `scripts/linear-git-status.sh`,
`scripts/risk-tier.sh`, `scripts/setup-branch-protection.sh`, `scripts/validate.sh` and
`templates/plan.md`. The lock also lists `scripts/ai-suite-sync.sh` and
`.github/workflows/ai-suite.yml`, which are not from ai-suite but the same in all four.

1. Never edit a copied file or add a file to a copied directory here. Change it in ai-suite,
   then bring all four repositories to the same ai-suite commit in one round with
   `scripts/ai-suite-sync.sh --update <ai-suite checkout>`, one pull request per repository,
   and confirm with `scripts/ai-suite-sync.sh --compare <the other three checkouts>`. CI runs
   `scripts/ai-suite-sync.sh --check` and `scripts/validate.sh` on every pull request.
2. Plan with the `planner` agent (`/plan`), create and split Linear issues with the
   `create-linear-issue` skill, implement one issue with the `implementer` agent, review with
   `/review`, let the `advisor` agent route unclear work, and write commits with the
   `conventional-commit` skill. Where an agent, skill or command is not loaded, as in a session
   started outside this repository, read its file under `.claude/` and follow it.
3. Every pull request runs `code-review` and `security-review` from `claude-review.yml` and
   ticks exactly one risk tier in the pull request template. `REVIEW.md`,
   `.github/risk-tiers.conf`, `.github/CODEOWNERS` and `.github/pull_request_template.md`
   belong to this repository; every `high` path is also in CODEOWNERS, and a high-tier change
   needs a person's approval.
4. Plans live in `docs/plans/{research,backlog,implementing,done}/`, also in repositories that
   keep their other documents in `doc/`. A project that spans repositories has one plan, in the
   repository with most of its issues. Every new or moved plan needs its `nav` entry in
   `docs-site/zensical.toml` of kulturtelefon-website.
5. Linear is the workspace `kulturtelefon`, team `KUL`. Besides its ai-suite category label,
   every issue has exactly one `repo:` label, and every commit names its issue in a
   `Refs KUL-<n>` line. Without Linear tools, stop and say so; never track work in the
   repository instead.
6. Plans written before ai-suite stay where they are and keep their ticket IDs. Their status
   lines are dated snapshots; where they differ from Linear, Linear is right. Such a plan
   without a Linear project gets one before its next ticket is implemented, with one issue per
   open ticket titled `<ticket ID> <summary>`.

<!-- END ai-suite -->
