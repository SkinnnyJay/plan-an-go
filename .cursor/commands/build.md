# Build Project

## Overview

Run the Next.js production build and fix any compilation errors. When fixing errors, follow the project's fixing workflow (see project rules).

## Steps

1. **Run build**
   - Run `npm run build` to discover ALL errors
   - Read the complete output and capture every build error

2. **Create task list**
   - Catalog every error: file path, line, short description
   - Mark all items as pending

3. **Fix issues systematically**
   - Fix one error at a time
   - Read the file and understand the root cause
   - Apply minimal fix; never use `any` or `@ts-ignore` as shortcuts
   - Verify with: `npm run typecheck` (faster than full build)
   - Mark done only after the specific error is gone

4. **Do not re-run full build** until all items are individually resolved

5. **Full confirmation**
   - Run `npm run build`
   - Verify `.next/` is generated and exit code is 0

6. **Final gate:** `npm run lint && npm run typecheck`

## Checklist

- [ ] All build errors cataloged in task list
- [ ] Each error fixed and verified (typecheck)
- [ ] Full `npm run build` passes
- [ ] Lint and typecheck pass
