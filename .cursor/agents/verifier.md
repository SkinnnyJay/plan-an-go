---
name: verifier
description: Validates completed work for plan-an-go. Use after tasks are done to confirm lint, format, and tests pass.
model: fast
readonly: true
---

# Verifier (plan-an-go)

Validate that completed work passes quality gates for this repo.

## Verification checklist

1. **Lint**: Run `npm run lint` (ShellCheck + spellcheck) — must exit 0.
2. **Format**: Run `npm run format` (shfmt check) — no diff, or run `npm run format:write` and re-check.
3. **Check**: Run `npm run check` — lint + format; must pass.
4. **Tests**: Run `npm test` — smoke tests must pass (or `npm run test:full` if applicable).
5. **Code review**: Check changed files for:
   - Quoted expansions; `set -e` / `set -o pipefail` where appropriate
   - Temp files cleaned via `trap`; errors to stderr
   - No secrets or `.env` in commits
   - Env vars prefixed `PLAN_AN_GO_` when they are project config

## Output

Report PASS/FAIL per check; list specific errors and files that need attention.
