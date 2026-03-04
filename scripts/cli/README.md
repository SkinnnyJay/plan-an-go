# CLI scripts

Entrypoints and helpers for the plan-an-go pipeline. Run from **repo root** so `PLAN.md` and `tmp/` (progress log, history log, temp files) resolve correctly.

## Main entrypoints

| Script | Role | Usage |
|--------|------|--------|
| `plan-an-go.sh` | **Implementer** — implements one task from the plan | `./scripts/cli/plan-an-go.sh [--cli claude\|codex\|cursor-agent]` |
| `plan-an-go-forever.sh` | **Orchestrator** — loop: implement → validate | `./scripts/cli/plan-an-go-forever.sh [parent_loops] [child_loops] [--no-validate] [--no-slack\|--slack-enable] [--stream] [--plan PATH] [--workspace DIR] [--out-dir DIR] [--clean-after] [--force] [--cli …]` |
| `plan-an-go-validate.sh` | **Validator** — audits implementer output, updates plan | `./scripts/cli/plan-an-go-validate.sh <implementer_output_file> [--cli …]` |

## CLI variants

Same behavior, fixed CLI: `plan-an-go-claude.sh`, `plan-an-go-codex.sh`, `plan-an-go-cursor-agent.sh` (and `-forever`, `-validate` variants). These wrappers resolve their path so you can run them from any directory (e.g. `./scripts/cli/plan-an-go-claude.sh` from repo root).

## Wizard

| Script | Purpose |
|--------|---------|
| `plan-an-go-wizard.sh` | Guided flow: PRD wizard (questions/config) → review PRD → update PRD → validate → write file → optional launch (forever with `--plan`). Use `plan-an-go wizard` or `npm run plan-an-go:wizard`. Steps are separate scripts under `cli/wizard/` and accept args; state is in `tmp/wizard-state`. |
| `cli/wizard/wizard-step-1-prd.sh` | PRD path + prompt (+ CLI); runs `plan-an-go prd`. |
| `cli/wizard/wizard-step-2-review-prd.sh` | Review PRD, collect revision notes. |
| `cli/wizard/wizard-step-3-update-prd.sh` | Update PRD from revisions (calls `plan-an-go prd --in … --prompt …`). |
| `cli/wizard/wizard-step-4-validate-prd.sh` | Validate PRD file (exists, non-empty, structure). |
| `cli/wizard/wizard-step-5-write-file.sh` | Checkpoint: file written at step 1 path. |
| `cli/wizard/wizard-step-6-launch.sh` | Ask to launch `plan-an-go forever --plan PLAN.md`; optionally generate PLAN from PRD first. |

Config: `cli/wizard/wizard-config.json` (defaults for path, CLI, options). Pass args to skip prompts (e.g. `--prd-out PRD.md --prompt "..."`). Orchestrator supports `--skip N` to skip steps 1..N.

## Helpers

| Script | Purpose |
|--------|---------|
| `plan-an-go-slack-update.sh` | Slack posting (sourced by forever when `PLAN_AN_GO_USE_SLACK=true`; Slack is off by default). |
| `plan-an-go-file-watch.sh` | Watch repo files while pipeline runs |
| `plan-an-go-task-watcher.sh` | Live task list from plan (`--plan PATH`, `--once`, `--minimal`, `--minimal-before N`, `--minimal-after N`, etc.). Invoked as `plan-an-go task-watcher` (full) or `plan-an-go task-watcher-minimal` (minimal: 5 before/5 after incomplete); npm: `plan-an-go-task-watcher` or `task:watcher`. |
| `plan-an-go-plan-check.sh` | Plan completion check (used by orchestrator) |
| `plan-an-go-split-run.sh` | **Command:** open native terminal with top/bottom split (top = task watcher, bottom = forever). Use `npm run plan-an-go-split -- [top args] -- [bottom args]`. |

## Output directory and workspace

- **`--out-dir DIR`** — (Entry script: `plan-an-go run|forever|planner|prd`.) Use `DIR` for generated files and as workspace: run/forever implement in `DIR`; planner writes `DIR/PLAN.md`; prd writes `DIR/PRD.md`. Dir is created if missing. Use unique dirs per project (e.g. `./example/todo`).
- **`--workspace DIR`** — Run from `DIR`; plan path is relative to workspace. Passed by the entry script; overridden by `--out-dir` when both are present.
- **`--clean-after`** (forever only) — After exit, remove workspace contents. **Requires `--force`.** Only when workspace is a subdir of the script repo. See `docs/ENV-README.md`.

## Env

- `PLAN_FILE` — Plan file path (default `PLAN.md`)
- `PLAN_AN_GO_CLI` — `claude` \| `codex` \| `cursor-agent`
- `PLAN_AN_GO_CLI_FLAGS` — Extra flags passed to the CLI (shared). When unset, `PLAN_AN_GO_CLAUDE_FLAGS` or `PLAN_AN_GO_CODEX_FLAGS` are used for the selected CLI.
- `PLAN_AN_GO_SLACK_*` — Slack tokens (see `.env.sample`); only used when `PLAN_AN_GO_USE_SLACK=true` (Slack off by default). Used by `plan-an-go-slack-update.sh`.
