# Run Tests

## Overview

Execute the full test suite and systematically fix any failures. When fixing failures, follow the project's fixing workflow (see project rules).

## Steps

1. **Run test suite**
   - Run `npm test` to discover ALL failures
   - Read the complete output and capture every failing test

2. **Create task list**
   - Catalog every failing test: file path, test name, short description
   - Mark all items as pending

3. **Fix issues systematically**
   - Fix one test at a time
   - Read the test and source file to understand root cause
   - Apply minimal fix
   - Verify with: `npx vitest run <test-file>`
   - Mark done only after it passes

4. **Do not re-run full suite** until every item is individually resolved

5. **Full confirmation**
   - Run `npm test` again
   - If regressions appear, add them to the task list and fix

6. **Final gate:** `npm run lint && npm run typecheck`

## Checklist

- [ ] All test failures cataloged in task list
- [ ] Each failure fixed and verified individually
- [ ] Full `npm test` passes
- [ ] Lint and typecheck pass
