# Code Review (plan-an-go)

Review changes for correctness and plan-an-go conventions. Report findings with severity and file:line.

## Steps

1. **Inspect**: `git diff` for all changes.
2. **Review against**:
   - Unquoted expansions; missing `set -e` / `set -o pipefail`
   - Temp files without `trap` cleanup; errors to stdout instead of stderr
   - Env vars: use `PLAN_AN_GO_` prefix (see docs/ENV-README.md)
   - Script naming: `plan-an-go-*.sh`; two-space indent
   - Meaningful comments only; no emoji
3. **Report**: Severity (MUST FIX, SHOULD FIX, SUGGESTION) and file:line for each finding.

## Checklist

- [ ] Logic and quoting reviewed
- [ ] Naming and style match AGENTS.md / rules
- [ ] No secrets or .env in changes
