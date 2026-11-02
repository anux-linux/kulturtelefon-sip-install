## Increment
One sentence: what exists after this issue that did not exist before.

## Where
Files, modules and functions to create or change, with paths.

## How
Concrete approach and interfaces (signatures, data shapes, behavior). Enough to implement
without further questions.

## Constraints
Language and style rules, performance, security, compatibility, what must not change.

## Tests
What the tests must check, per case: input, expected result, edge cases and error cases.
Where the tests live and how to run them.

## Linked issues
- Blocked by: <planning issue, if any>
- Blocks: <review issue>, <deployment issue>

## Done when
- [ ] The increment is implemented as described.
- [ ] The tests above exist and pass (command: `...`).
- [ ] The change is committed, with this issue's key in the commit message.

Review and production are handled by the linked `review` and `deployment` issues.
