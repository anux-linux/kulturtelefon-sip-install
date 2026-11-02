## Change under review
What is being released and which `implementing` issues it covers.

## Goal
No bad code reaches production.

## Risk
Low | Medium | High, with the reason (see the PR template). High needs a person to approve.

## How to revert
Exact steps, and anything a revert does not undo.

## Steps
- [ ] Open the PR with Summary, Linked issues, Testing, Risk and How to revert filled in.
- [ ] Automated checks pass (typecheck, lint, tests, build).
- [ ] Code review done; all comments resolved.
- [ ] Deployed to **staging**; staging checks below pass.
- [ ] PR approved and merged to `main`.
- [ ] Production deployed (see the linked `deployment` issue).
- [ ] Production tested; checks below pass.

## Staging checks
What to click, call or observe, and the expected result.

## Production checks
Smoke tests to run on production after the deploy, and the expected result.

## Linked issues
- Blocked by: <implementing issues>
- Related: <deployment issue>

## Done when
- [ ] The PR is merged to `main`.
- [ ] The change is deployed to production.
- [ ] The change is tested on production.
