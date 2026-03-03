# Format and Lint

## Overview

Fix all linting and formatting issues across the project. When fixing remaining issues, follow the project's fixing workflow (see project rules).

## Steps

1. **Run lint**
   - Run `npm run lint` to discover ALL issues
   - Read the complete output

2. **Auto-fix**
   - Run `npm run lint --fix` and `npm run format:write` to fix what can be auto-fixed

3. **Create task list**
   - Run `npm run lint` again
   - Catalog every remaining error: file path, rule, description
   - Mark all items as pending

4. **Fix issues systematically**
   - Fix one issue at a time
   - Read the file and understand the violation
   - Apply minimal, correct fix (never use `any` to silence type errors)
   - Verify with: `npx eslint <file>` or `npx biome check <file>`
   - Mark done only after it passes

5. **Do not re-run full lint** until all items are individually resolved

6. **Full confirmation**
   - Run `npm run lint`; handle any regressions

7. **Final gate:** `npm run typecheck`

## Checklist

- [ ] Auto-fix applied (lint --fix, format:write)
- [ ] All remaining issues cataloged in task list
- [ ] Each issue fixed and verified per file
- [ ] Full `npm run lint` passes
- [ ] Typecheck passes
