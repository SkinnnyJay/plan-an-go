# PLAN — &lt;Project or feature name&gt;

**Default output file:** `./PLAN.md` (override with `--out` when using the planner script.)

---

## Top info (metadata)

- **Title:** One-line name of the plan.
- **Scope:** 1–3 sentences: what is in scope and what is out of scope.
- **Owner / context:** Optional; who or what system this plan belongs to.
- **Last updated:** Optional date or revision.

---

## Summary

2–5 bullet points: high-level outcomes, key deliverables, and how “done” is defined at the plan level.

---

## Milestones and tasks

Use this structure so downstream scripts (e.g. `plan-an-go-plan-check.sh`, `plan-an-go.sh`, `plan-an-go-forever.sh`) can parse the file. **Required:** Wrap all milestones and task lines in a single `<work>...</work>` block so only that content is parsed (see README). Non-compliant plans trigger a warning; use `--strict` to reject them.

### Milestone format

- One milestone per section.
- Header line: **`**M<n>:0 - Milestone title**`**
  - `n` = milestone number (1, 2, 3, …).
  - Use `:0` for the milestone header; task IDs under it use `:1`, `:2`, etc.

### Task format

- Each task is a single line: checkbox, then task ID, then description.
- **Break work into granular, actionable tasks.** One concrete step per task; use subtasks (M<n>:<id>.<sub>) for multi-part steps. Be specific: include paths, artifact names, or measurable behavior (e.g. "Add GET /users in src/routes/users.ts", "Write 1–10 to ./test.log, one per line").
- **Checkbox:** `[ ]` = incomplete, `[x]` = complete. Use only these two forms.
- **Task ID:** `M<n>:<id>` for top-level tasks, or `M<n>:<id>.<sub>` for subtasks (e.g. `M1:1`, `M1:2.1`).
- **Pattern:** `[ ] - M<n>:<id>- Short description` or `[x] - M<n>:<id>- Short description`
  - Important: a **dash** must follow the task ID (e.g. `M1:1-`) before the description so parsers can detect the format.
- **Dependencies (for multi-agent runs):** To allow the orchestrator to assign only tasks whose prerequisites are done, add `(after M<n>:<id>)`, `(requires M<n>:<id>)`, or `(when M<n>:<id> complete)` to the end of the task description. Example: `[ ] - M2:1- Add API route (after M1:2)`.

### Marking tasks complete

- **Incomplete:** `[ ]` (space inside the brackets).
- **Complete:** When a task is finished and validated, change that line to `[x]` (letter x inside the brackets). Scripts and the implementer/validator use this to track progress.
- Only mark a task `[x]` after the work is done and any validation (e.g. tests, review) passes. Do not mark complete until then.

Example structure (wrap in `<work>...</work>`; task lines must start with `[ ]` or `[x]`):

```markdown
<work>
**M1:0 - Foundation**
[ ] - M1:1- Set up repo and tooling
[ ] - M1:2- Define API contract
[ ] - M1:2.1- OpenAPI spec
[ ] - M1:2.2- Auth schema

**M2:0 - Core feature**
[ ] - M2:1- Implement feature X
[ ] - M2:2- Add tests
</work>
```

---

## 100% success criteria

List **testable, verifiable** conditions that must all be true for the plan to be considered **100% complete**. The implementer and validator use these to decide “done.” Every major deliverable should have at least one criterion. Include: “All tasks in this PLAN are marked [x].”

- Criterion 1: e.g. “All tasks marked [x] in this PLAN.”
- Criterion 2: e.g. “File ./out.log exists and contains exactly 10 lines.”
- Criterion 3: e.g. “npm run test passes.”
- … (add as many as needed; keep concrete and checkable)

---

## Notes / assumptions

Optional: dependencies, risks, assumptions, or links to PRD/PRs.
