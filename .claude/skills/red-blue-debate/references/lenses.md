# Lenses per artifact type

The red team picks the set that matches the artifact and may add one if the artifact needs it.
The blue team and the mediator use the same lenses to check that nothing was skipped.

## Plan
- **Scope:** is anything missing, or anything included that the goal does not need?
- **Sequencing:** wrong order, hidden dependencies, steps that cannot be done independently.
- **Unknowns:** decisions or facts assumed instead of known; research that should come first.
- **Rollback and failure:** what if step N fails halfway? Can each step be undone?
- **Verification:** how would we know it worked? Is "done" measurable?
- **Cost and effort:** underestimated work, ongoing maintenance, money.

## Implementation (code, config, pipeline)
- **Correctness:** edge cases, error paths, concurrency, idempotency.
- **Security:** input handling, secrets, permissions, injection, fail-open guards.
- **Failure handling:** timeouts, retries, partial failure, data loss.
- **Operability:** logging, alerts, deploy and rollback, behavior under load.
- **Tests:** what is not covered; would the tests catch the failures above?
- **Fit:** does it follow the repo's conventions and layers, or fight them?
- **Weight:** is there more here than the goal needs? Name the code, option, abstraction or
  dependency that could go, and what already exists instead (`path:line` of the helper, the
  standard-library call, the installed package). Never count the repo's own required layers,
  validation, logging or tests as weight.

## Architecture, deployment and setup documents
- **Single points of failure** and blast radius of each component.
- **Rollback and recovery:** can a bad deploy be undone without customers noticing? Backups tested?
- **Drift:** does the document match what actually exists? Check the repo and config.
- **Security and access:** exposure, secrets handling, least privilege.
- **Cost and scale:** what grows with usage, what is idle.
- **Operability:** who gets paged, how is it diagnosed, what is manual?

## Proposed feature or future development
- **Need:** is there evidence users want it? What is the cost of not doing it?
- **Alternatives:** a simpler way, an existing tool, or the do-nothing baseline.
- **Maintenance:** ongoing cost, new failure modes, new dependencies.
- **Reversibility:** can it be removed if it fails? What does it lock in?
- **Side effects:** effect on existing features, data, security, performance, support load.
- **Sequencing:** is this the right time, given what else is planned?
