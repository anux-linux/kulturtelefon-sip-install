## Summary
<!-- What changes and why, in two or three sentences. -->

## Linked issues
<!-- Linear keys, e.g. KUL-12. Every commit names its issue in a `Refs KUL-<n>` line. -->

## Testing
<!-- What you ran and what you saw. Paste the result, not "tested". An install on a test host counts: name the Debian release. -->
- [ ] `git ls-files -z 'src/*.sh' | xargs -0 -n1 sh -n` passes
- [ ] `scripts/ai-suite-sync.sh --check` and `scripts/validate.sh` pass

## Risk
<!-- Tick exactly one. The change sets the tier, not the author: the merge check recomputes it
     from .github/risk-tiers.conf and blocks if you tick a lower one. -->
- [ ] **Low**: docs, templates, README, LICENSE
- [ ] **Medium**: agents, skills, commands, scripts, CLAUDE.md, anything not listed
- [ ] **High**: hooks, `.claude/settings.json`, CI workflows, CODEOWNERS, REVIEW.md, risk-tiers.conf, anything under `src/` (needs a person to approve)

Why this tier:

## How to revert
<!-- Exact steps, e.g. `git revert <sha>`, plus anything a revert does not undo (a host already installed, a firewall rule saved on a node). -->

## Checklist
- [ ] No credentials, tokens, host lists or customer data (this repository is public)
- [ ] README and `CLAUDE.md` match the change
- [ ] Every review finding is fixed or answered with a reason
