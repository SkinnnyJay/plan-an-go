# Prompt assets

Optional prompt templates for the implementer, validator, and **planner**. The CLI scripts build prompts inline by default; this folder is for overrides or customizations (e.g. `template.md`, `planning.md`) when wired into your workflow.

## PLAN format (template and example)

- **`template.md`** — Defines how a PLAN document should be structured so downstream scripts can parse it. Includes:
  - **Top info:** title, scope, owner, last updated
  - **Summary:** high-level outcomes and definition of done
  - **Milestones and tasks:** `**M<n>:0 - Title**` for milestones; `[ ] - M<n>:<id>- Description` or `[x] - ...` for tasks (required for `plan-an-go-plan-check.sh`, `plan-an-go.sh`, `plan-an-go-forever.sh`)
  - **100% success criteria:** conditions that must all be true for the plan to be complete
  - **Notes / assumptions:** optional

- **`example.md`** — A filled-in example PLAN that follows `template.md` (e.g. “Blue auth-driven feature button”).

Default output file for a generated plan is **`./PLAN.md`** (overridable with the planner’s `--out` option).

## Planner

- **`planning.md`** — Prompt used by **`scripts/cli/plan-an-go-planner.sh`** to ask the CLI (claude / codex / cursor-agent) to produce a PLAN that matches the agreed format in `template.md`.

### Using the planner

From the repo root (or with paths adjusted):

```bash
# Generate PLAN.md from a PRD (or any input document)
./scripts/cli/plan-an-go-planner.sh PRD.md

# Output to a specific file
./scripts/cli/plan-an-go-planner.sh --out ./my-plan.md PRD.md

# Use a freeform prompt instead of a file
./scripts/cli/plan-an-go-planner.sh --prompt="I need to add a new feature button. It has to be blue, when clicked do x. Auth driven."

# Choose CLI (same as plan-an-go.sh)
./scripts/cli/plan-an-go-planner.sh --cli cursor-agent --prompt="New API endpoint for users list"
```

The planner uses the same `--cli` and `--cli-flags` as `plan-an-go.sh`, so you can keep one CLI (e.g. `cursor-agent` or `claude`) for both planning and implementation.
