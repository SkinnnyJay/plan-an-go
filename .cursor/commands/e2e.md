# Run E2E Tests

## Overview

Execute Playwright E2E tests and systematically fix any failures. When fixing failures, follow the project's fixing workflow (see project rules).

## Steps

1. **Run E2E suite**
   - Run `npm run test:playwright` to discover ALL failures
   - Check `./logs/playwright-results.json` for detailed failure context

2. **Create task list**
   - Catalog every failing spec: file path, test name, short description
   - Mark all items as pending

3. **Fix issues systematically**
   - Fix one spec at a time
   - Read the spec file and relevant source code
   - Apply minimal fix
   - Verify with: `npx playwright test <spec-file>`
   - For debugging: `npx playwright test <spec-file> --trace on`
   - Mark done only after it passes

4. **Do not re-run full suite** until all items are individually resolved

5. **Full confirmation**
   - Run `npm run test:playwright`; handle any regressions

6. **Final gate:** `npm run lint && npm run typecheck`

## Checklist

- [ ] All E2E failures cataloged in task list
- [ ] Each spec fixed and verified individually
- [ ] Full `npm run test:playwright` passes
- [ ] Lint and typecheck pass
