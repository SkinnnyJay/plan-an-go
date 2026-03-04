# CLAUDE.md

Project-level guidance for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/settings) (claude.ai/code). Claude Code loads this file at the start of sessions. File-type rules and skills live in `.claude/rules/` and `.claude/skills/`. See **AGENTS.md** for repository guidelines, testing, and coding style.

## Project overview

plan-an-go is a **plan-driven CLI orchestrator** (Bash, Node for npm scripts) that automates an implement → validate loop. It reads a plan file (`PLAN.md`) with milestones and checkbox tasks, then runs LLM-powered agents (Claude, Codex, or Cursor) in a loop until all tasks are marked complete.

## Commands

Full argument tables, examples, and when to use each: **docs/COMMANDS.md**.

```bash
# Run one implementer cycle
npm run plan-an-go

# Run the full orchestrator loop (implement → validate, repeating)
npm run plan-an-go-forever
npm run plan-an-go-forever -- 100 50 --plan PLAN.md --cli claude --no-slack

# Run with concurrent agents
npm run plan-an-go-forever -- --concurrency 3 --no-slack

# Validate implementer output
npm run plan-an-go-validate -- <implementer_output_file>

# Generate a plan from a prompt
npm run plan-an-go-planner -- --prompt="Build a todo app" --out ./PLAN.md

# Watch task progress live (full list or minimal: 5 before/5 after incomplete)
npm run plan-an-go-task-watcher -- --plan PLAN.md
npm run task:watcher -- --plan PLAN.md

# Reset completed tasks back to incomplete
npm run reset -- --plan PLAN.md

# Interactive onboarding (menu + optional env review, then run a command)
npm run plan-an-go-onboard

# Run the count example (verifies setup)
npm run example:count

# Build into a specific directory (unique per run; no overwrite)
npm run plan-an-go-prd    -- --out-dir ./example/todo    --prompt="Todo list app"
npm run plan-an-go-planner -- --out-dir ./example/todo    --in ./example/todo/PRD.md
npm run plan-an-go-forever -- --out-dir ./example/todo    --plan PLAN.md --no-slack
# Optional: remove generated files after pipeline exits (requires --force)
npm run plan-an-go-forever -- --out-dir ./example/todo --plan PLAN.md --clean-after --force --no-slack

# System setup
npm run setup          # interactive install + auth + verify
npm run verify         # check CLIs and keys
```

All scripts accept `--` before extra args when run via npm. Make targets (`make run`, `make run-forever`, etc.) wrap the same scripts.

## Architecture

```
scripts/plan-an-go          (entry point: resolves root, routes subcommands via exec)
  │
  ├─ scripts/cli/plan-an-go-forever.sh    ORCHESTRATOR (main loop)
  │    │
  │    ├─ plan-an-go.sh                   IMPLEMENTER (Agent 1)
  │    │    └─ scripts/extract-incomplete-tasks.sh   (token optimization)
  │    │
  │    ├─ plan-an-go-validate.sh          VALIDATOR (Agent 2)
  │    │    └─ scripts/extract-incomplete-tasks.sh
  │    │
  │    └─ plan-an-go-slack-update.sh      (optional Slack posting)
  │
  ├─ plan-an-go-planner.sh               PLANNER (generates PLAN.md)
  ├─ plan-an-go-task-watcher.sh           LIVE DISPLAY (fswatch-based)
  └─ plan-an-go-reset.sh                 RESET ([x] → [ ])
```

**Two-agent loop:** The orchestrator marks the first incomplete task `[IN_PROGRESS]`, spawns the Implementer to work on it, then spawns the Validator to audit. The Validator must achieve ≥8/10 confidence for a task to stay marked `[x]`; otherwise it reverts to `[ ]`.

**Token optimization:** `extract-incomplete-tasks.sh` strips completed tasks from the plan before sending to the LLM, reducing prompt size significantly as the plan progresses.

**Concurrency:** With `--concurrency N`, the orchestrator marks N tasks with `[IN_PROGRESS]:[AGENT_01]` through `[AGENT_N]` and runs N implementers in parallel. Each agent is filtered to its assigned task via `PLAN_AN_GO_AGENT_ID`.

**CLI abstraction:** All three CLIs (claude, codex, cursor-agent) receive prompts via stdin. CLI-specific args are built in a `CLI_ARGS` array per script. Model selection is via `PLAN_AN_GO_CLAUDE_MODEL` / `PLAN_AN_GO_CODEX_MODEL` env vars.

## Plan file format

Plans **must** wrap all milestones and tasks in one or more `<work>...</work>` blocks (compliant format); multiple chunks are supported. Only that block is parsed; prompt or example text outside it is ignored. Non-compliant plans trigger a warning; use `--strict` (or `PLAN_AN_GO_STRICT=true`) to reject them.

```markdown
# PLAN — Title

## Top info (metadata)
- **Title:** ...
- **Scope:** ...

## Milestones and tasks

<work>
**M1:0 - Milestone title**
[ ] - M1:1- Task description
[ ] - M1:2- Another task
[ ] - M1:2.1- Subtask (dotted ID)

**M2:0 - Second milestone**
[ ] - M2:1- Task description
</work>

## 100% success criteria
- All tasks in this PLAN are marked [x].
- ...
```

Key parsing rules:
- Milestone headers: `**M<n>:0 - Title**`
- Task lines: `[ ] - M<n>:<id>- Description` (incomplete) or `[x] - M<n>:<id>- Description` (complete)
- A dash must follow the task ID (e.g. `M1:1-`) for parsers to detect the format
- **Dependencies (multi-agent):** In the task description you can add `(after M<n>:<id>)`, `(requires M<n>:<id>)`, or `(when M<n>:<id> complete)`. The orchestrator assigns only tasks whose dependency is already [x]; it skips ineligible tasks and picks the next so agents don't block on unfinished prerequisites.
- `[IN_PROGRESS]` or `[IN_PROGRESS]:[AGENT_NN]` is appended by the orchestrator; when a task is marked complete, `[IN_PROGRESS]:[AGENT_NN]` is converted to `[AGENT_NN]` so the plan keeps which agent completed it
- **`<work>...</work>`:** Required for compliant plans. Only lines between these tags are used for task counting, marking, and implementer prompts. Use `--strict` to refuse non-compliant plans.

## Key environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `PLAN_FILE` | Plan file path | `PLAN.md` |
| `PLAN_AN_GO_CLI` | CLI to use | `claude` |
| `PLAN_AN_GO_CLAUDE_MODEL` | Claude model ID | `claude-sonnet-4-20250514` |
| `PLAN_AN_GO_CODEX_MODEL` | Codex model ID | (CLI default) |
| `PLAN_AN_GO_CLI_FLAGS` | Shared extra CLI flags | (none) |
| `PLAN_AN_GO_CLAUDE_FLAGS` | Claude-specific flags | (none) |
| `PLAN_AN_GO_CODEX_FLAGS` | Codex-specific flags | (none) |
| `PLAN_AN_GO_USE_SLACK` | Enable Slack posting | `false` |
| `PLAN_AN_GO_ROOT` | Override operating root | (repo root) |
| `PLAN_AN_GO_TMP` | Directory for progress log, history log, tail log, temp files | `./tmp` |

Copy `.env.sample` to `.env` for full list including Slack tokens.

## Output directory and cleanup

- **`--out-dir DIR`** (run, forever, planner, prd): Use `DIR` for generated files and as the implementer workspace instead of repo root. Dir is created if missing. Use **unique, hardcoded dirs** per project so the suite can run without overwriting (e.g. `./example/todo`, `./example/journal`, `./example/youtube-clone`).
  - **run / forever:** implementer runs in `DIR`; plan is `DIR/PLAN.md` if not overridden.
  - **planner:** writes `DIR/PLAN.md` unless `--out` is set.
  - **prd:** writes `DIR/PRD.md` unless `--out` is set.
- **`--clean-after`** (forever only): After the pipeline exits (all complete, max iterations, or Ctrl+C), remove all contents of the workspace directory. **Requires `--force`.** Cleanup runs only when the workspace is a **subdirectory** of the script repo (never repo root). Example: `npm run plan-an-go-forever -- --out-dir ./example/one --clean-after --force --no-slack`.

## Code conventions

- All pipeline scripts are **bash** (not POSIX sh). Use `#!/bin/bash`.
- Argument parsing uses a `for arg in "$@"` loop with `PREV_ARG` to handle both `--flag=value` and `--flag value` forms. This pattern is repeated across scripts (no shared arg-parsing utility exists yet).
- Workspace resolution (cd + absolute path for `PLAN_FILE`) is also repeated per script.
- Prompts are built by writing to temp files and passed via stdin to the CLI. Temp files are cleaned via `trap ... EXIT`.
- Structured output markers: `------START: IMPLEMENTER------` / `------END: IMPLEMENTER------` (and same for VALIDATOR).
