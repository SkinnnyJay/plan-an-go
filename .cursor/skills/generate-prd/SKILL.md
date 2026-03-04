---
name: generate-prd
description: Generate a detailed, descriptive, structured PRD (Product Requirements Document) as markdown. Use when creating or refining a PRD, starting from a prompt or existing doc, with default PRD.md or custom output path/arguments.
---

# Generate PRD

Generate a **Product Requirements Document (PRD)** as markdown that is detailed, descriptive, and structured. Output can target the default `PRD.md` or a path/arguments you specify. The PRD is designed to be used as input to `plan-an-go-planner.sh` for generating a PLAN.

## Project context

- plan-an-go is a **Bash CLI orchestrator** (see `CLAUDE.md`, `AGENTS.md`). The planner reads a PRD (or prompt) and produces a PLAN; the implementer/validator work from the PLAN.
- A well-structured PRD clarifies goals, scope, requirements, and success criteria before planning. When drafting requirements, follow **Bash best practices** in any tasks that will later touch scripts (see `AGENTS.md`).

## Assets to use

- **`assets/prompts/prd-template.md`** — Canonical PRD structure. Read when generating so output matches the expected format.
- **`assets/prompts/prd.md`** — Prompt rules for PRD content (detailed, descriptive, structured; output PRD markdown only, no preamble/code fences).

**Script option:** `npm run plan-an-go-prd -- --prompt="..." --out PRD.md` or `npm run plan-an-go-prd -- --in existing-doc.md --out PRD.md`

## When to use

- User asks for a "PRD", "product requirements", "generate-prd", or "write a PRD".
- Starting a new product or feature and need a structured requirements document before planning.
- Refining or expanding an existing doc into a full PRD.
- Need markdown that can be passed to `scripts/cli/plan-an-go-planner.sh` as input.

## PRD format (summary)

Use the structure in `assets/prompts/prd-template.md`. Essentials:

1. **Title:** `# PRD — <Title>`
2. **Overview:** 2–4 sentences (what, who, why).
3. **Goals:** Bullet list of one-line outcomes.
4. **Non-goals:** Explicit out-of-scope items.
5. **User personas / stakeholders:** Primary and optional secondary.
6. **Requirements:** Functional (F1, F2, …) and non-functional (NF1, NF2, …).
7. **Success criteria:** Testable conditions that define "done".
8. **Notes / assumptions / risks:** Optional.

Example:

```markdown
# PRD — Feature name

## Overview
Brief description of the product or feature and why it matters.

## Goals
- **Goal 1:** One-line outcome.
- **Goal 2:** …

## Non-goals (out of scope)
- What we are not doing.

## Requirements
### Functional
- **F1:** Testable behavior.
### Non-functional
- **NF1:** Performance or quality requirement.

## Success criteria
- Criterion 1: testable condition.
```

## Process

1. Gather context or ask 1–2 clarifying questions (question + options; fill **Chosen** when answered).
2. Emit full PRD from `assets/prompts/prd-template.md`. Be detailed and descriptive; requirements should be specific and traceable.
3. Suggest: write to default `PRD.md` or the path the user requested; then optionally run `npm run plan-an-go-planner -- PRD.md` to generate a PLAN.

## Commands

- Generate PRD (CLI): `npm run plan-an-go-prd -- --prompt="..." [--out PRD.md]`
- Generate PRD from file: `npm run plan-an-go-prd -- --in existing-doc.md [--out PRD.md]`
- Generate PLAN from PRD: `npm run plan-an-go-planner -- PRD.md`

## Rules

- Output only the PRD markdown; no preamble, no code fences.
- Match the structure in `prd-template.md` so downstream tools and the planner can consume it.
- Requirements (F1, F2, NF1, …) should be testable or verifiable where possible.
