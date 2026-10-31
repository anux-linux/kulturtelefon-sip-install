---
name: conventional-commit
description: Write commit messages in Conventional Commits style. Use whenever creating a git commit or proposing a commit message.
---

# Conventional commits

Format: `<type>(<optional scope>): <imperative summary, max 72 chars>`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`.

Rules:
- Summary in imperative mood, no trailing period.
- Body (optional) explains *why*, wrapped at 72 columns.
- One logical change per commit.
- Breaking changes: add `!` after the type and a `BREAKING CHANGE:` footer.

Before committing, look at `git diff --staged` and make sure the message matches what is actually staged.
