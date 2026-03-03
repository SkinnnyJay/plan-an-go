# Code Review

## Overview

Review current changes for quality, correctness, and project conventions. Report findings with clear severity and file:line references.

## Steps

1. **Inspect changes**
   - Run `git diff` to see all changes

2. **Review against criteria**
   - Logic errors, null handling, race conditions
   - Private members use `private` keyword (no underscore prefix)
   - Zod schemas for external data validation
   - API routes: Zod validation at boundary, standard Next.js route handlers (see .cursor/rules/api-patterns.mdc)
   - No `any` types; no `eslint-disable` without justification
   - Functions under ~80 lines, files under ~400 lines

3. **Report findings**
   - Use severity: MUST FIX, SHOULD FIX, SUGGESTION
   - Include file:line references for each finding

## Review Checklist

- [ ] Logic and edge cases reviewed
- [ ] Naming and style match project conventions
- [ ] No inappropriate `any` or disables
- [ ] API routes validate input with Zod and follow project patterns
- [ ] Size limits (function/file) considered
