# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-03-04

### Added

- **Orchestrator:** Implement → validate loop until all plan tasks are complete or loop limits are reached.
- **Implementer:** Reads `PLAN.md`, picks an incomplete task, runs an LLM agent to implement it, and updates the plan.
- **Validator:** Audits implementer output; tasks require ≥8/10 confidence to stay marked complete.
- **Planner:** Generate a plan from a prompt or PRD (`plan-an-go-planner`, `--prompt`, `--out`).
- **PRD generator:** Generate a Product Requirements Document from a prompt or input file (`plan-an-go-prd`).
- **Task watcher:** Live view of plan progress (requires `fswatch`); full list or minimal mode (5 before/5 after incomplete); supports in-progress and agent IDs when using concurrency.
- **Output directory:** `--out-dir DIR` for run, forever, planner, and prd; build into a dedicated directory without overwriting repo root. Optional `--clean-after --force` (forever only) to remove workspace contents after exit.
- **Plan format:** Plans must wrap milestones and tasks in `<work>...</work>`; only that block is parsed. `--strict` (or `PLAN_AN_GO_STRICT=true`) rejects non-compliant plans.
- **Task dependencies:** In task text use `(after M2:1)`, `(requires M3:2)`, or `(when M2:1 complete)`; orchestrator assigns only tasks whose dependency is already marked complete.
- **Reset:** Reset completed tasks `[x]` to incomplete `[ ]` with optional milestone filter and backup.
- **CLI support:** Claude (Anthropic), Codex (OpenAI), and Cursor agent; select via `PLAN_AN_GO_CLI` or `--cli`.
- **Concurrency:** Run N implementer agents in parallel (`--concurrency N`); tasks marked `[IN_PROGRESS]:[AGENT_NN]`.
- **Slack (optional):** Post pipeline updates to a channel; off by default, fails gracefully if tokens are unset.
- **Token optimization:** Strip completed tasks from the plan before sending to the LLM to reduce prompt size.
- **Setup and verify:** Interactive `npm run setup`, `install-clis`, `auth-cli`, and `verify` for CLIs and API keys.
- **Examples:** Count (`examples/count`), journal, todo, vacation-airbnb, youtube-clone—each with PRD/README/run.sh; `npm run example:count`, `example:todo`, etc. Script `scripts/cli/scripts/plan-work-section.sh` for focused work sections.
- **Documentation:** `docs/COMMANDS.md` with full argument tables and examples for all subcommands; `docs/ENV-README.md` for environment variables.
- **System:** `scripts/system/install-plan-an-go.sh` and `plan-an-go install-plan-an-go` for install/link workflow.
- **Quality gates:** ShellCheck, shfmt; `npm run check` and `npm run ci` (lint → format → test).

### Changed

- **Agent/IDE config:** Cursor, Claude, and Codex rules and agents aligned; removed `api-patterns.mdc`; removed coverage and e2e commands from Cursor. Code-style and fixing-workflow rules updated.
- **Env and CI:** `.env.sample` expanded with `PLAN_AN_GO_*` vars; `.github/workflows/ci.yml` and `.gitignore` updated.
- **CLI scripts:** Consistent `set -e` and small fixes across plan-an-go-* and wizard steps.

### Removed

- **Spellcheck:** cspell and spellcheck removed from lint; `npm run lint` is ShellCheck only. Reduces dependency footprint; content is typically LLM-generated.
- **Tracked runtime artifacts:** `task-*-completed.txt` and `tmp/*` no longer committed; use `tmp/` and ignore patterns instead.

[1.0.0]: https://github.com/SkinnnyJay/plan-an-go/releases/tag/v1.0.0
