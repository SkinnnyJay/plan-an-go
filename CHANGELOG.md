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
- **Task watcher:** Live view of plan progress (requires `fswatch`); supports in-progress and agent IDs when using concurrency.
- **Reset:** Reset completed tasks `[x]` to incomplete `[ ]` with optional milestone filter and backup.
- **CLI support:** Claude (Anthropic), Codex (OpenAI), and Cursor agent; select via `PLAN_AN_GO_CLI` or `--cli`.
- **Concurrency:** Run N implementer agents in parallel (`--concurrency N`); tasks marked `[IN_PROGRESS]:[AGENT_NN]`.
- **Slack (optional):** Post pipeline updates to a channel; off by default, fails gracefully if tokens are unset.
- **Token optimization:** Strip completed tasks from the plan before sending to the LLM to reduce prompt size.
- **Setup and verify:** Interactive `npm run setup`, `install-clis`, `auth-cli`, and `verify` for CLIs and API keys.
- **Example:** Minimal count example in `examples/count`; run with `npm run example:count`.
- **Quality gates:** ShellCheck, cspell, shfmt; `npm run check` and `npm run ci` (lint → format → test).

[1.0.0]: https://github.com/SkinnnyJay/plan-an-go/releases/tag/v1.0.0
