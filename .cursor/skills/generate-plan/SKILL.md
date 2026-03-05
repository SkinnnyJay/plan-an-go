---
name: generate-plan
description: Generate a standard Plan-an-go loop plan as markdown. Use when starting a new Plan-an-go loop, creating a PRD/PLAN, or when the user asks for a plan in the plan-an-go format. Keep the session open: ask many clarifying questions first, converse until you have full context, then generate the plan.
---

# Generate Plan

Generate a **Plan-an-go loop plan** as markdown that works with `plan-an-go-plan-check.sh` and the implementer/validator pipeline. **Keep the session open and conversational:** ask lots of clarifying questions about the project before generating; only emit the full plan when you have enough detail and the user is ready.

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

1. **Metadata (required at top):** Include a plan-an-go metadata block as the first content, wrapped in HTML comments so previews do not render it. Use current date/time in ISO 8601 and set `generated_cli` to this assistant (e.g. `cursor-agent`, `claude`, `codex`):

<!-- 
```plan_meta_data
{"created_by":"generate-plan","created_at":"<ISO 8601>","last_updated":"<ISO 8601>","generated_cli":"cursor-agent"}
```
-->

2. **Title:** `# PLAN — <Title>`
3. **Top info:** `## Top info` with **Title**, **Scope**.
4. **Summary:** Bullet outcomes and definition of done.
5. **Milestones:** Header `**M<n>:0 - Title**` (only `:0` for milestone headers).
6. **Tasks:** `[ ] - M<n>:<id>- Description` or `[x] - ...`. Dash after ID required (`M1:1-`). Subtasks: `M1:2.1-`, etc.

Example:

```markdown
## Milestones and tasks

**M1:0 - Milestone One**
[ ] - M1:1- First task
[ ] - M1:2.1- Subtask

**M2:0 - Milestone Two**
[ ] - M2:1- Next task
```

7. **100% success criteria** (optional): e.g. all tasks marked `[x]`.

## Process

1. **Conversation first — do not rush to the plan.** Keep the session open. Ask clarifying questions in rounds (e.g. 3–5 questions per message) so you gather full project context. For each question, offer concrete options when helpful and record the user’s answer (e.g. **Chosen:** …) so the conversation continues with that context.
2. **Topics to clarify (ask many of these):** Project type and goal; scope (in/out); tech stack, language, and tooling; existing codebase or greenfield; constraints (time, dependencies, compliance); success criteria and definition of done; priorities and phases; risks, assumptions, and open questions; who will implement (solo vs team) and how tasks will be validated. Revisit or drill down if answers are vague.
3. **Continue the conversation** until the user confirms they have given enough detail or asks you to generate the plan. Acknowledge answers and, if needed, ask follow-ups before moving on. It is fine to have multiple back-and-forth turns before any plan is emitted.
4. **Only then** emit the full plan from `assets/prompts/template.md`. Prefer 3–8 milestones, 2–6 tasks per milestone. After emitting, offer to refine (e.g. add/remove tasks, adjust scope) so the session stays open.
5. Suggest: `scripts/cli/plan-an-go-plan-check.sh <file>` after generation.

## Commands

- Generate: `npm run plan-an-go-planner -- --prompt="..." --out PLAN.md`
- Validate plan: `scripts/cli/plan-an-go-plan-check.sh PLAN.md`
- Run loop: `PLAN_FILE=PLAN.md npm run plan-an-go` or `npm run plan-an-go-forever`

## Rules

- **Session stays open:** You are having a conversation; do not generate the plan in the first reply. Ask questions, listen, then generate when ready.
- **Clarifying questions are required:** Aim to ask many questions (across the topics above) so the plan is accurate and actionable. It is better to over-clarify than to guess.
- Milestone headers: only `**M<n>:0 - Title**` (never `:1`, `:2` in the header).
- Every checkbox line must include task id: `[ ]` / `[x]` with `M<n>:<id>-`.
- One line per task when possible; second line only for acceptance criteria.
