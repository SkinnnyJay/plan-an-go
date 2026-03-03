# Coverage Report

## Overview

Generate a test coverage report and identify low-coverage areas. Use to assess test health and suggest tests for gaps.

## Steps

1. **Run coverage**
   - Run `npm run test:coverage`

2. **Locate artifacts**
   - Confirm report and artifacts in `.generated/coverage/`

3. **Summarize**
   - Report overall percentages: lines, branches, functions, statements

4. **Flag gaps**
   - Identify files below the 70% coverage threshold

5. **Suggest tests**
   - Recommend specific tests or scenarios for low-coverage areas

## Checklist

- [ ] Coverage run completed
- [ ] Artifacts present in `.generated/coverage/`
- [ ] Summary with percentages provided
- [ ] Files below 70% flagged
- [ ] Suggestions for low-coverage areas provided
