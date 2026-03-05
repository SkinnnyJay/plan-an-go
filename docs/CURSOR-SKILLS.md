# Cursor Agent Skills (plan-an-go)

This repo includes **Cursor Agent Skills** that help you create high-quality PRDs and plans in the format plan-an-go expects. They are valuable when you want to start a new loop, draft a PLAN or PRD with the right structure, or get conversational help before (or instead of) running the CLI.

---

## Overview

| Skill | Purpose | When to use |
|-------|---------|-------------|
| **generate-prd** | Produce a structured Product Requirements Document (PRD) as markdown. | You have an idea or prompt and want a detailed, traceable PRD before planning. |
| **generate-plan** | Produce a plan-an-go–format PLAN (milestones and tasks) as markdown. | You want a runnable PLAN, with the AI asking clarifying questions first. |

Both skills output markdown that matches the templates used by `plan-an-go-prd` and `plan-an-go-planner`, so you can paste into files, run the scripts, or refine in chat.

---

## generate-prd

**What it does:** Generates a **PRD** (Product Requirements Document) that is detailed, descriptive, and structured. The output follows `assets/prompts/prd-template.md` and is suitable as input to the planner.

**Why it’s valuable:** A good PRD clarifies goals, scope, requirements, and success criteria before you plan. The skill ensures the right structure (overview, goals, non-goals, requirements F1/F2, NF1/NF2, success criteria) so downstream tools and the planner can use it.

**How to use in Cursor:**

- In chat, mention the skill so the agent loads it: **`@generate-prd`** or **`@.cursor/skills/generate-prd`**.
- Describe your product or feature (e.g. “Todo app with filters and persistence”) or ask for a PRD from an existing doc. The agent will use the skill to produce PRD markdown.
- You can then save the output as `PRD.md` and run:  
  `npm run plan-an-go-planner -- PRD.md`

**CLI equivalent:**  
`npm run plan-an-go-prd -- --prompt="..." --out PRD.md` or `--in existing-doc.md --out PRD.md` (see [COMMANDS.md](COMMANDS.md#plan-an-go-prd-generate-prd)).

---

## generate-plan

**What it does:** Generates a **plan-an-go loop plan** as markdown: milestones and tasks in the format expected by `plan-an-go-plan-check.sh` and the implementer/validator pipeline. The skill is designed to **keep the session conversational**: it asks clarifying questions first and only emits the full plan when you have enough context.

**Why it’s valuable:** Rushing to a plan often misses scope, constraints, or priorities. This skill encourages multiple rounds of questions (project type, scope, stack, success criteria, risks, etc.) so the final plan is accurate and actionable. The output matches `assets/prompts/template.md` and passes plan-check.

**How to use in Cursor:**

- In chat, mention the skill: **`@generate-plan`** or **`@.cursor/skills/generate-plan`**.
- Say you want a “plan-an-go plan” or “loop plan” (or that you’re starting a new implementation loop). The agent will ask clarifying questions; answer them and add any detail you care about.
- When you’re ready, ask it to generate the plan. It will emit the full PLAN markdown. You can then save it as `PLAN.md` and run:  
  `npm run plan-an-go` or `npm run plan-an-go-forever`

**CLI equivalent:**  
`npm run plan-an-go-planner -- --prompt="..." --out PLAN.md` or pass a PRD file (see [COMMANDS.md](COMMANDS.md#plan-an-go-planner-generate-plan)).

---

## Quick reference

| Goal | Use skill | Then |
|------|-----------|------|
| Turn an idea into a structured PRD | `@generate-prd` | Save as `PRD.md`; optionally `npm run plan-an-go-planner -- PRD.md` |
| Get a PLAN with guided clarification | `@generate-plan` | Save as `PLAN.md`; run `npm run plan-an-go` or `plan-an-go-forever` |
| PRD then PLAN via CLI only | — | `npm run plan-an-go-prd -- --prompt="..."` then `npm run plan-an-go-planner -- PRD.md` |

Skill definitions live in `.cursor/skills/generate-plan/` and `.cursor/skills/generate-prd/` (each has a `SKILL.md` with full instructions for the agent).
