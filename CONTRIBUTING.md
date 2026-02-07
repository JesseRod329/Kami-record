# Contributing to KAMI BOT

## Development Workflow

- Branch naming: `codex/<feature-name>`
- Commit style: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)
- Merge policy: squash merge via pull request
- Direct pushes to `main` are not allowed

## Pull Request Requirements

1. Keep each PR focused on one logical feature or fix.
2. Ensure CI passes (`lint`, `build`, `test`).
3. Add or update tests for behavior changes.
4. Update `CHANGELOG.md` for user-visible changes.
5. If dependencies change, update `docs/dependencies.md` and `NOTICE` as needed.

## Commit Message Format

```text
type(scope): short summary

Why this change was needed and what behavior changed.
```

## Local Validation

```bash
./scripts/lint.sh
swift build --package-path KAMIBotApp
./scripts/test.sh
```

## Code of Conduct

All contributors must follow `CODE_OF_CONDUCT.md`.
