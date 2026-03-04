# Lint and Format (plan-an-go)

Fix all lint and formatting issues. Follow the project fixing workflow (see rules).

## Steps

1. **Discover**: Run `npm run check` and read the full output.
2. **Auto-fix**: Run `npm run format:write` for shell formatting; fix spellcheck with `npm run spellcheck:fix` if needed.
3. **Task list**: Catalog every remaining ShellCheck/spellcheck error (file, rule, description).
4. **Fix one at a time**: Apply minimal fix, then verify with `shellcheck <file>` or `npm run spellcheck`.
5. **Full confirmation**: Run `npm run check` again.

## Checklist

- [ ] format:write and spellcheck:fix applied
- [ ] Remaining issues cataloged and fixed per file
- [ ] `npm run check` passes
