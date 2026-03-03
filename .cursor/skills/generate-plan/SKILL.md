---
name: generate-plan
description: Generate a standard Plan-an-go loop plan as markdown with optional clarifying questions. Use when starting a new Plan-an-go loop, creating a PRD/PLAN, or when the user asks for a plan in the plan-an-go format.
---

# Generate Plan

Generate a **standard Plan-an-go loop plan** as markdown, compatible with `plan-an-go-plan-check.sh` and the Plan-an-go implementer/validator pipeline. The plan can be driven by clarifying questions (question + options) before generation.

## When to use

- User asks for a "plan-an-go plan", "loop plan", "PRD for Plan-an-go", or "generate-plan"
- Starting a new Plan-an-go implementation loop and need a correctly formatted PLAN/PRD
- Need to produce markdown that passes `./plan-an-go-plan-check.sh`

## Standard plan format (plan-an-go loop)

The output must follow this structure so `plan-an-go-plan-check.sh` and the implementer can parse it:

### 1. Title and summary

```markdown
# PLAN — <Short title>

## Executive summary

<1–3 sentences. What this plan covers and the intended outcome.>
```

### 2. Optional: Clarifying questions block

Before generating milestones, you may ask clarifying questions. Format each as:

```markdown
## Clarifying questions

- **Question:** <One clear question?>
  **Options:** A) <option A>, B) <option B>, C) <option C>
  **Chosen:** _(filled after user/agent answers)_
```

If the user or agent provides answers, fill **Chosen** and use them to shape milestones and tasks.

### 3. Milestones (section headers)

Use **exactly** this form so the plan checker recognizes milestones:

- Milestone line: a line that **starts with** `**M<n>:0 - Title**` (no `###` prefix; plan-check expects line start `**M<num>:0`).
- Task line: `- [ ] - M<n>:<id>- Description` (checkbox, space-dash-space, `M<n>:<id>-`, space, description). For `plan-an-go-plan-check.sh` the line must **start with** optional space then `[` (so use `[ ] - M<n>:<id>-` at line start, not `- [ ] -`).

Example:

```markdown
## Milestones and tasks

**M1:0 - Milestone One Title**

[ ] - M1:1- First task description; acceptance criteria if needed.
[ ] - M1:2- Second task.
[ ] - M1:2.1- Subtask (optional dotted id).

**M2:0 - Milestone Two Title**

[ ] - M2:1- First task of second milestone.
```

- Use `[ ]` for incomplete, `[x]` for complete.
- Subtasks: use dotted id, e.g. `M1:2.1-`, `M1:2.2-`.
- No letter after the numeric id (use `M1:1-` not `M1:1a-`).

### 4. Optional: Flow / scope

```markdown
## Important flow

1. Take the next logical incomplete task.
2. Work through it (plan, implement, validate).
3. Mark done in this file; commit; repeat.
```

## Process

1. **Gather context**: If the user has a goal or scope, use it. If not, ask one or two clarifying questions (question + options).
2. **Resolve options**: If questions were asked, wait for or use provided answers and note "Chosen" in the questions block.
3. **Generate markdown**: Emit the full plan using the format above. Prefer 3–8 milestones and 2–6 tasks per milestone; add subtasks only when needed.
4. **Output**: Write to the path requested (e.g. `PLAN.md`, `PRD.md`) or show in chat. Recommend running `./plan-an-go-plan-check.sh <file>` after generation.

## Commands

- Generate plan (interactive or from template): `npm run generate-plan` or `./scripts/generate-plan.sh`
- Validate generated plan: `./plan-an-go-plan-check.sh PLAN.md`
- Use as PRD for Plan-an-go: `PRD_FILE=PLAN.md ./plan-an-go.sh`

## Template and example

Use the example file as the canonical format reference:

- **Example template**: `templates/plan-an-go-plan.example.md`
- Copy or merge from it when generating a new plan so structure and regex patterns stay valid.

## Rules

- Never emit milestone headers like `**M1:1 - Title**` (id must be `:0` for milestones).
- Never use checkbox lines without a task id: every `[ ]` / `[x]` line must include `M<n>:<id>-`.
- Keep task descriptions one line when possible; add a second line only for acceptance criteria.
- If the user provides a question + options, include them in "Clarifying questions" and fill "Chosen" when answered.
