# Run Tests (plan-an-go)

Run the shell test suite and fix failures. Follow the project fixing workflow (see rules).

## Steps

1. **Discover**: Run `npm test` (smoke) or `npm run test:full`; read full output.
2. **Task list**: Catalog every failing test (file, test name, short description).
3. **Fix one at a time**: Read test and source, apply minimal fix, verify with `./__tests__/run-tests.sh --verbose` for the affected test.
4. **Full confirmation**: Run `npm test` (or `npm run test:full`); then `npm run check`.

## Checklist

- [ ] All failures cataloged
- [ ] Each failure fixed and verified
- [ ] `npm test` and `npm run check` pass
