# plan-an-go

Automated **implement → validate** pipeline driven by a PRD (Product Requirements Document). An orchestrator runs an Implementation Agent and a Validation Agent in a loop until all tasks are done or you stop it.

## System setup

Before running the pipeline, install the CLI you’ll use and authenticate it:

- **One-shot:** From repo root, `./scripts/system/setup.sh` (interactive install + auth + verify). To install everything: `./scripts/system/setup.sh all`.
- **Step by step:**
  - **Install CLIs:** `./scripts/system/install-clis.sh` (interactive) or `./scripts/system/install-clis.sh all` or list names: `claude`, `codex`, `jq`, `fswatch`, `cursor-agent` (check-only).
  - **Authenticate:** `./scripts/system/auth-cli.sh` (interactive) or `./scripts/system/auth-cli.sh all`. Uses web login unless you set `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` in `.env`. Log out: `./scripts/system/auth-cli.sh --logout`.
  - **Verify:** `./scripts/system/verify.sh` (fails on missing CLIs/keys); `./scripts/system/verify.sh --force` to warn but exit 0.

See `scripts/system/README.md` for details.

## Quick start

1. **Create a PRD** — Add a `PRD.md` in the repo root with checklist tasks (`[ ]` / `[x]`).
2. **Configure env** — Copy `.env.sample` to `.env` and set `PLAN_AN_GO_CLI` (e.g. `claude`, `codex`, `cursor-agent`).
3. **Run** — From repo root:
   - One iteration: `npm run plan-an-go`
   - Continuous loop: `npm run plan-an-go-forever`
   - Validate only: `npm run plan-an-go-validate -- <implementer_output_file>`

## Commands

| Command | Description |
|--------|-------------|
| `npm run plan-an-go` | Run one implementer cycle (one task from PRD). |
| `npm run plan-an-go-forever` | Run implementer → validator in a loop (default 100 parent × 50 child). |
| `npm run plan-an-go-validate -- <file>` | Run validator on a saved implementer output file. |

Options for the forever loop: `--no-validate`, `--no-slack`, `--stream`, `--cli codex`, `--tail=file.log`. See `./scripts/cli/plan-an-go-forever.sh` for full usage.

## Environment

- `PRD_FILE` — Path to PRD (default: `PRD.md`).
- `PLAN_AN_GO_CLI` — LLM CLI: `claude`, `codex`, or `cursor-agent`.
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` — Optional; if set, system auth uses the key instead of web login for that provider.
- `USE_SLACK` / `PLAN_AN_GO_SLACK_*` — Optional Slack notifications (see `.env.sample`).

## Project layout

- `scripts/system/` — Setup: `setup.sh`, `install-clis.sh`, `auth-cli.sh`, `verify.sh` (see `scripts/system/README.md`).
- `scripts/cli/` — Entrypoints: `plan-an-go.sh`, `plan-an-go-forever.sh`, `plan-an-go-validate.sh`, plus helpers.
- `assets/prompts/` — Optional prompt templates (scripts build prompts inline by default).
- `MAKEFILE` — Convenience targets that wrap the above commands.
