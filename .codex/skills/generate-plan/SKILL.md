---
name: generate-plan
description: Generate a standard Plan-an-go loop plan as markdown with optional clarifying questions. Use when starting a new Plan-an-go loop, creating a PRD/PLAN, or when the user asks for a plan in the plan-an-go format.
---

# Generate Plan

Generate a **Plan-an-go loop plan** as markdown that works with `plan-an-go-plan-check.sh` and the implementer/validator pipeline. Optionally use clarifying questions (question + options) before generating.

## Project context

- plan-an-go is a **Bash CLI orchestrator** (see `CLAUDE.md`, `AGENTS.md`). Pipeline lives in `scripts/cli/` and `scripts/system/`; entry point is `scripts/plan-an-go`.
- Plans often include tasks that add or change **Bash scripts**. When drafting such tasks, follow **Bash best practices** from `AGENTS.md`: `#!/bin/bash`, `set -e` and `set -o pipefail`, quote expansions (`"$var"`), use `mktemp` and `trap cleanup EXIT` for temp files, errors to stderr and `exit 1`, script names `plan-an-go-*.sh`, env vars `PLAN_AN_GO_*`.

## Assets to use

- **`assets/prompts/template.md`** — Canonical PLAN structure. Read when generating so output matches plan-check and implementer.
- **`assets/prompts/planning.md`** — Output rules (PLAN markdown only, no preamble/code fences; preserve tasks when refining).

**Script option:** `npm run plan-an-go-planner -- --prompt="..." --out PLAN.md` or `npm run plan-an-go-planner -- PRD.md`

## When to use

- User asks for a "plan-an-go plan", "loop plan", or "generate-plan".
- Starting a new implementation loop and need a correctly formatted PLAN/PRD.
- Need markdown that passes `scripts/cli/plan-an-go-plan-check.sh`.

## Plan format (summary)

Use the structure in `assets/prompts/template.md`. Essentials:

1. **Title:** `# PLAN — <Title>`
2. **Top info:** `## Top info` with **Title**, **Scope**.
3. **Summary:** Bullet outcomes and definition of done.
4. **Milestones:** Header `**M<n>:0 - Title**` (only `:0` for milestone headers).
5. **Tasks:** `[ ] - M<n>:<id>- Description` or `[x] - ...`. Dash after ID required (`M1:1-`). Subtasks: `M1:2.1-`, etc.

Example:

```markdown
## Milestones and tasks

**M1:0 - Milestone One**
[ ] - M1:1- First task
[ ] - M1:2.1- Subtask

**M2:0 - Milestone Two**
[ ] - M2:1- Next task
```

6. **100% success criteria** (optional): e.g. all tasks marked `[x]`.

## Process

1. Gather context or ask 1–2 clarifying questions (question + options; fill **Chosen** when answered).
2. Emit full plan from `assets/prompts/template.md`. Prefer 3–8 milestones, 2–6 tasks per milestone.
3. Suggest: `scripts/cli/plan-an-go-plan-check.sh <file>` after generation.

## Commands

- Generate: `npm run plan-an-go-planner -- --prompt="..." --out PLAN.md`
- Validate plan: `scripts/cli/plan-an-go-plan-check.sh PLAN.md`
- Run loop: `PLAN_FILE=PLAN.md npm run plan-an-go` or `npm run plan-an-go-forever`

## Rules

- Milestone headers: only `**M<n>:0 - Title**` (never `:1`, `:2` in the header).
- Every checkbox line must include task id: `[ ]` / `[x]` with `M<n>:<id>-`.
- One line per task when possible; second line only for acceptance criteria.
