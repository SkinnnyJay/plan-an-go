# CLI scripts

Entrypoints and helpers for the plan-an-go pipeline. Run from **repo root** so `PRD.md` and `progress.txt` resolve correctly.

## Main entrypoints

| Script | Role | Usage |
|--------|------|--------|
| `plan-an-go.sh` | **Implementer** — implements one task from the PRD | `./scripts/cli/plan-an-go.sh [--cli claude\|codex\|cursor-agent]` |
| `plan-an-go-forever.sh` | **Orchestrator** — loop: implement → validate | `./scripts/cli/plan-an-go-forever.sh [parent_loops] [child_loops] [--no-validate] [--no-slack] [--stream] [--cli …]` |
| `plan-an-go-validate.sh` | **Validator** — audits implementer output, updates PRD | `./scripts/cli/plan-an-go-validate.sh <implementer_output_file> [--cli …]` |

## CLI variants

Same behavior, fixed CLI: `plan-an-go-claude.sh`, `plan-an-go-codex.sh`, `plan-an-go-cursor-agent.sh` (and `-forever`, `-validate` variants).

## Helpers

| Script | Purpose |
|--------|---------|
| `plan-an-go-slack-update.sh` | Slack posting (sourced by forever when `USE_SLACK=true`) |
| `plan-an-go-file-watch.sh` | Watch repo files while pipeline runs |
| `plan-an-go-task-watcher.sh` | Live task list from PRD (`--prd PATH`) |
| `plan-an-go-plan-check.sh` | PRD completion check (used by orchestrator) |

## Env

- `PRD_FILE` — PRD path (default `PRD.md`)
- `PLAN_AN_GO_CLI` — `claude` \| `codex` \| `cursor-agent`
- `PLAN_AN_GO_CLI_FLAGS` — Extra flags passed to the CLI
- `PLAN_AN_GO_SLACK_*` — Slack tokens (see `.env.sample`) when `USE_SLACK=true`; used by `plan-an-go-slack-update.sh`
