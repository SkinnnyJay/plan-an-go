# Wizard (guided PRD → plan → run)

The wizard runs a guided flow: PRD (step 1) → review (2) → update PRD from revisions (3) → validate (4) → write checkpoint (5) → optional launch with `plan-an-go forever` (6). Invoke via `plan-an-go wizard` or `npm run plan-an-go:wizard`.

## Config and state

- **`wizard-config.json`** — Defaults for PRD path, plan path, and CLI. Step 1 reads questions/defaults from here when run interactively.
- **State** — `$PLAN_AN_GO_TMP/wizard-state` (default `./tmp/wizard-state`) holds `WIZARD_PRD_PATH`, `WIZARD_CLI`, `WIZARD_REVISIONS_FILE`, etc., for later steps.

## Templates (no hardcoded prompts)

Steps that call the planner or PRD scripts use the same **template/prompt standards** as the rest of plan-an-go:

- **Step 1** runs `plan-an-go prd`, which reads prompts from **`assets/prompts/`** (or `PLAN_AN_GO_PROMPTS_DIR`). See `assets/prompts/README.md` and `docs/ENV-README.md`.
- **Step 3** (update PRD from revisions) uses the template **`assets/prompts/prd-revision.md`** (or `PLAN_AN_GO_PRD_REVISION_PROMPT_FILE`). Placeholder `{{REVISION_NOTES}}` is replaced with the user’s revision text.
- **Step 6** runs `plan-an-go planner` and `plan-an-go forever`; the planner reads from `assets/prompts/` (planning.md, template.md) per `PLAN_AN_GO_PROMPTS_DIR`.

Override template locations in `.env`; see **docs/ENV-README.md** for `PLAN_AN_GO_PROMPTS_DIR` and `PLAN_AN_GO_PRD_REVISION_PROMPT_FILE`.
