# Lint and Format (plan-an-go)

Fix all lint and formatting issues. Follow the project fixing workflow (see rules).

## Steps

1. **Discover**: Run `npm run check` and read the full output.
2. **Auto-fix**: Run `npm run format:write` for shell formatting.
3. **Task list**: Catalog every remaining ShellCheck error (file, rule, description).
4. **Fix one at a time**: Apply minimal fix, then verify with `shellcheck <file>` or `npm run lint`.
5. **Full confirmation**: Run `npm run check` again.

## Checklist

- [ ] format:write applied
- [ ] Remaining issues cataloged and fixed per file
- [ ] `npm run check` passes
