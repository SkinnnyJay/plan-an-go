# PLAN — Write numbers 1–10 to test.txt

**Default output file:** `./PLAN.md` (override with `--out` when using the planner script.)

---

## Top info (metadata)

- **Title:** Write numbers 1–10 to ./test.txt (one per line).
- **Scope:** Create or overwrite `./test.txt` with exactly 10 lines: the integers 1 through 10, one per line. No other files or behaviors are in scope.
- **Owner / context:** Plan-an-go script run; intended for iteration (e.g. run script against plan and iterate up to 10 times).
- **Last updated:** 2025-03-03

---

## Summary

- Create or overwrite the file `./test.txt` in the project root.
- Write the numbers 1 through 10, each on its own line (newline between each number).
- The resulting file must contain exactly 10 lines.
- Plan is suitable for running the plan-an-go script against it and iterating (e.g. 10 times) until success criteria are met.
- “Done” means `./test.txt` exists, has 10 lines, and each line is the string "1", "2", … "10" in order.

---

## Milestones and tasks

### Milestone format

- One milestone per section.
- Header line: **`**M<n>:0 - Milestone title**`**
  - `n` = milestone number (1, 2, 3, …).
  - Use `:0` for the milestone header; task IDs under it use `:1`, `:2`, etc.

### Task format

- Each task is a single line: checkbox, then task ID, then description.
- **Checkbox:** `[ ]` = incomplete, `[x]` = complete. Use only these two forms.
- **Task ID:** `M<n>:<id>` for top-level tasks, or `M<n>:<id>.<sub>` for subtasks (e.g. `M1:1`, `M1:2.1`).
- **Pattern:** `[ ] - M<n>:<id>- Short description` or `[x] - M<n>:<id>- Short description`
  - Important: a **dash** must follow the task ID (e.g. `M1:1-`) before the description so parsers can detect the format.

**M1:0 - Create output file**
[x] - M1:1- Create or overwrite ./test.txt in the project root [IN_PROGRESS]
[ ] - M1:2- Write the number 1 on line 1
[ ] - M1:3- Write the number 2 on line 2
[ ] - M1:4- Write the number 3 on line 3
[ ] - M1:5- Write the number 4 on line 4
[ ] - M1:6- Write the number 5 on line 5
[ ] - M1:7- Write the number 6 on line 6
[ ] - M1:8- Write the number 7 on line 7
[ ] - M1:9- Write the number 8 on line 8
[ ] - M1:10- Write the number 9 on line 9
[ ] - M1:11- Write the number 10 on line 10

**M2:0 - Validate output**
[ ] - M2:1- Confirm ./test.txt exists and has exactly 10 lines
[ ] - M2:2- Confirm each line is the expected number (1, 2, … 10) in order

---

## 100% success criteria

- `./test.txt` exists in the project root.
- `./test.txt` contains exactly 10 lines.
- Line 1 is "1", line 2 is "2", … line 10 is "10" (no extra spaces or characters).
- All tasks in this PLAN are marked [x].
- Plan-an-go script can be run against this plan and iterated (e.g. 10 times) until these criteria pass.

---

## Notes / assumptions

- Output path is relative to the project root: `./test.txt`.
- One number per line; no trailing blank line required unless you want 11 lines (then success criteria would need to allow that). As written, “10 lines” means 10 lines of content.
- Intended usage: run your script against this plan and iterate up to 10 times until validation passes.
