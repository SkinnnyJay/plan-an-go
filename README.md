<img src="assets/images/readme-header.png" alt="plan-an-go - Orchestrate Your CLI Workflows" width="100%" />

# plan-an-go

Automated **implement → validate** pipeline driven by a plan file (e.g. `PLAN.md`). An orchestrator runs an Implementation Agent and a Validation Agent in a loop until all tasks are done or you stop it.

## Install

- **From npm (global):** `npm install -g plan-an-go` then run `plan-an-go` from any directory. Copy `.env.sample` from the package (e.g. `$(npm root -g)/plan-an-go/.env.sample`) to a location you’ll use for config, rename to `.env`, and set `PLAN_AN_GO_ROOT` to your project directory (or pass `--root /path/to/project` when you run commands).
- **From npm (project):** `npm install plan-an-go` and use via `npx plan-an-go` or `npm run` scripts; put `.env` in the project root and set `PLAN_AN_GO_ROOT` to that path if needed.
- **From source:** Clone the repo, copy `.env.sample` to `.env`, then run from repo root with `npm run plan-an-go` / `npm run plan-an-go-forever` (see [Quick start](#quick-start)).

## System setup

Before running the pipeline, install the CLI you’ll use and authenticate it:

- **One-shot:** From repo root, `npm run setup` (interactive install + auth + verify). To install everything: `npm run setup -- all`.
- **Step by step:**
  - **Install CLIs:** `npm run install-clis` (interactive) or `npm run install-clis -- all`, or list names: `claude`, `codex`, `jq`, `fswatch`, `cursor-agent` (check-only).
  - **Authenticate:** `npm run auth-cli` (interactive) or `npm run auth-cli -- all`. Uses web login unless you set `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` in `.env`. Log out: `npm run auth-cli -- --logout`.
  - **Verify:** `npm run verify` (fails on missing CLIs/keys); `npm run verify -- --force` to warn but exit 0.

**Tip:** Setup is smoother if you already have the CLI you want to use installed and logged in. Set the default CLI in `.env` with `PLAN_AN_GO_CLI` (e.g. `claude`, `codex`, `cursor-agent`) so you always get the same one without passing `--cli` each time.

**Platforms:** `install-clis` supports **macOS** (darwin), **Linux**, and **Windows** (Git Bash / MSYS2 / Cygwin) via `scripts/system/install-clis-<platform>.sh`. A shared `scripts/system/platform.sh` provides `get_platform`, `stat_mtime`, and `install_hint` for other scripts.

See `scripts/system/README.md` for details.

## Quick start

1. **Create a plan** — Add a `PLAN.md` in the repo root with checklist tasks (`[ ]` / `[x]`).
2. **Configure env** — Copy `.env.sample` to `.env` and set `PLAN_AN_GO_CLI` (e.g. `claude`, `codex`, `cursor-agent`). See [Environment variables](docs/ENV-README.md) for all keys, defaults, and when to set them.
3. **Run** — From repo root:
   - One iteration: `npm run plan-an-go`
   - Continuous loop: `npm run plan-an-go-forever`
   - Validate only: `npm run plan-an-go-validate -- <implementer_output_file>`

## Full flow walkthrough

End-to-end example: **a fully functional todo list app** in modern React with Next.js and Tailwind, using **in-memory storage** (no database).

### 1. Workspace

Create a new Next.js app (or use an existing repo) and `cd` into it:

```bash
npx create-next-app@latest my-todo-app --typescript --tailwind --eslint --app --no-src-dir
cd my-todo-app
```

### 2. Generate a plan from a prompt

From the **plan-an-go repo root** (not inside `my-todo-app`), run the planner with a short prompt. It will produce a `PLAN.md` in the path you pass with `--out` (or give a path under your app and copy it in):

```bash
npm run plan-an-go-planner -- \
  --prompt="Build a todo list app in modern React with Next.js and Tailwind. The app should be fully functional: add, toggle complete, delete, and optionally clear completed. Use in-memory state only (no database)." \
  --out ./my-todo-app/PLAN.md \
  --cli codex
```

Or generate `PLAN.md` in the plan-an-go repo and then copy it into your app:

```bash
npm run plan-an-go-planner -- \
  --prompt="Build a todo list app in modern React with Next.js and Tailwind. Fully functional (add, toggle, delete, clear completed). In-memory only." \
  --out ./PLAN.md
cp PLAN.md /path/to/my-todo-app/
```

Edit the generated plan if you want (e.g. adjust milestones or success criteria).

### 3. Run the pipeline

From the **plan-an-go repo root**, point the orchestrator at your app and its plan:

```bash
# Option A: Build into a dedicated dir (unique per project; no overwrite). Use --out-dir:
npm run plan-an-go-prd     -- --out-dir ./example/todo --prompt="Todo app with shadcn"
npm run plan-an-go-planner -- --out-dir ./example/todo --in ./example/todo/PRD.md
npm run plan-an-go-forever -- --out-dir ./example/todo --plan PLAN.md --no-slack

# Option B: Explicit workspace and plan path
npm run plan-an-go-forever -- 100 50 \
  --workspace ./my-todo-app \
  --plan ./my-todo-app/PLAN.md \
  --cli codex \
  --no-slack
```

- **Implementer** reads the plan, picks an incomplete task (`[ ]`), implements it, and updates the plan (e.g. marks it `[x]`).
- **Validator** checks the work and the plan; the loop continues until all tasks are done or you stop it.

Optional: in another terminal, run the task watcher to see progress:

```bash
npm run plan-an-go-task-watcher -- --plan ./my-todo-app/PLAN.md
```

### 4. Optional: reset and re-run

To redo completed tasks (e.g. after changing the plan or the app), reset checkboxes to incomplete:

```bash
npm run reset -- --plan ./my-todo-app/PLAN.md
# Or only milestone 1:
npm run reset -- --plan ./my-todo-app/PLAN.md --milestone 1
```

Then run the pipeline again. By default, `reset` creates a `.bak` copy of the plan; use `--force` to skip the backup.

### 5. Done

When the loop finishes, your app has a plan-driven implementation and all plan tasks are marked complete. Run the app (e.g. `cd my-todo-app && npm run dev`) and verify the todo list behavior.

## Commands

| Command | Description |
|--------|-------------|
| `npm run plan-an-go` | Run one implementer cycle (one task from plan). |
| `npm run plan-an-go-forever` | Run implementer → validator in a loop (default 100 parent × 50 child). |
| `npm run plan-an-go-validate -- <file>` | Run validator on a saved implementer output file. |
| `npm run plan-an-go-task-watcher` | Live task list; pass `--plan PATH` etc. after `--`. |
| `npm run plan-an-go-planner` | Generate a plan from a prompt or PRD; pass `--prompt`, `--out`, `--cli` after `--`. |
| `npm run plan-an-go-prd` | Generate a PRD from a prompt or input doc; pass `--prompt`, `--in`, `--out`, `--cli` after `--`. |
| `npm run reset [-- --plan FILE] [-- --milestone N] [-- --force]` | Reset completed tasks `[x]` → `[ ]` in a plan; optional milestone; default backup is `<plan>.bak`. |
| `npm run example:count` | Run the [count example](#example-count) — prints log path at top, then streams output. |
| `npm run setup` | One-shot system setup (install CLIs + auth + verify). |
| `npm run install-clis [-- all]` | Install CLIs (interactive or `all`). |
| `npm run auth-cli [-- all]` | Authenticate CLIs. |
| `npm run verify [-- --force]` | Verify CLIs/keys; `--force` warns but exits 0. |
| `npm run lint` | Run ShellCheck on scripts and cspell on docs/source files. |
| `npm run lint:sh` | ShellCheck only (scripts and entry). |
| `npm run format` | Check shell script formatting (shfmt; requires `shfmt` installed). |
| `npm run format:write` | Fix shell script formatting. |
| `npm run check` | Lint + format check (run before commits). |
| `npm run ci` / `npm run build` | Full CI gate: lint → format check → test. Single command for CLI/CD; exit code = failed step or 0. |

**Linting and formatting:** Install [ShellCheck](https://github.com/koalaman/shellcheck) and [shfmt](https://github.com/mvdan/sh) (e.g. `brew install shellcheck shfmt` on macOS) to run `npm run lint` and `npm run format`. The repo uses `.shellcheckrc` and shfmt with `-i 2 -ci`. Use `make lint`, `make format`, `make format-write`, or `make check` for the same via Make. For CI/CD, run `npm run ci` or `make ci` (alias: `make build`) to run the full gate and get a single pass/fail exit code.

## Script arguments

All scripts are in `scripts/cli/`. Run from **repo root** via npm (pass extra args after `--`).

### plan-an-go-forever (orchestrator)

```text
npm run plan-an-go-forever -- [parent_loops] [child_loops] [options]
```

| Argument | Description |
|----------|-------------|
| `parent_loops` | Number of orchestrator iterations (default: 100). |
| `child_loops` | Max LLM calls per agent per iteration (default: 50). |
| `--no-validate` | Skip validator; implementer only. |
| `--no-threads` | Post Slack messages to channel (no threads). |
| `--stream` | Stream LLM output in real time (gray background). |
| `--no-slack` | Disable Slack (default). |
| `--slack-enable` | Enable Slack (opt-in; requires Slack tokens in `.env`; if unset or post fails, we warn and continue). |
| `--tail` | Append iteration output to `pipeline-tail.log`. |
| `--tail=FILE` | Append iteration output to FILE (e.g. `tail -f FILE` in another terminal). |
| `--workspace DIR` | Run from DIR (default: repo root). |
| `--plan FILE` | Plan file path (default: `PLAN.md`; relative to workspace). |
| `--out-dir DIR` | Same as workspace for this run: implement in DIR; plan at `DIR/PLAN.md`. Dir created if missing. Use unique dirs per project (e.g. `./example/todo`, `./example/journal`). |
| `--clean-after` | After exit, remove workspace contents. **Requires `--force`**; only when workspace is a subdir of repo. |
| `--force` | Required with `--clean-after` to confirm cleanup. |
| `--cli NAME` | CLI: `claude`, `codex`, or `cursor-agent` (default: from `PLAN_AN_GO_CLI` or `claude`). |
| `--cli-flags "FLAGS"` | Extra flags passed to the CLI (quoted string). |
| `--concurrency N` | Run N implementer agents in parallel; each picks one of the first N incomplete tasks. Tasks are marked `[IN_PROGRESS]:[AGENT_01]` … `[AGENT_N]` in the plan. Task watcher shows a yellow ● and agent id for each in-progress task (default: 1). |

### plan-an-go (implementer)

```text
npm run plan-an-go -- [options]
```

| Argument | Description |
|----------|-------------|
| `--workspace DIR` | Run from DIR. |
| `--plan FILE` | Plan file (or set `PLAN_FILE`). |
| `--cli NAME` | `claude`, `codex`, or `cursor-agent`. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |

### plan-an-go-validate (validator)

```text
npm run plan-an-go-validate -- <implementer_output_file> [options]
```

| Argument | Description |
|----------|-------------|
| `implementer_output_file` | Path to saved implementer stdout (required). |
| `--workspace DIR` | Run from DIR. |
| `--cli` / `--cli-flags` | Same as implementer. |

### plan-an-go-task-watcher (live task list)

```text
npm run plan-an-go-task-watcher -- [options]
```

| Argument | Description |
|----------|-------------|
| `--plan PATH` | Plan file (default: `./PLAN.md`). |
| `--once` | Single run, no file watch. |
| `--width N` | Terminal width for truncation. |
| `--max-rows N` | Max task rows. |
| `--ids-only` | Show only ID and checkmark. |
| `--minimal` | Show context around incomplete tasks only. |
| `--no-progress` | Hide progress bar. |
| `--no-color` | Disable color. |
| `--poll N` | fswatch poll interval (seconds). |

In-progress tasks (lines containing `[IN_PROGRESS]` or `[IN_PROGRESS]:[AGENT_NN]`) are shown with a **yellow ●**; when using `--concurrency N`, the agent id (e.g. `AGENT_01`) is shown so you can see which agent is handling each task.

Requires `fswatch` for watch mode (`brew install fswatch`).

### plan-an-go-prd (PRD generator)

Generates a structured Product Requirements Document (PRD) from a prompt or an input file. Default output is `./PRD.md`; use `--out` to override. The PRD can be passed to the planner to produce a PLAN.

```text
npm run plan-an-go-prd -- --prompt="Describe the product or feature"
npm run plan-an-go-prd -- --in notes.md [--out ./PRD.md]
```

| Argument | Description |
|----------|-------------|
| `--prompt="..."` | Use this string as input (product/feature description). |
| `--in PATH` | Input file to expand or structure as a PRD. |
| `--out PATH` | Output file (default: `./PRD.md`). |
| `--cli` / `--cli-flags` | Same as planner/implementer. |

## Supported CLIs and models

| CLI | Description | Model selection |
|-----|-------------|------------------|
| **claude** | Anthropic Claude CLI | Set `PLAN_AN_GO_CLAUDE_MODEL` in `.env` (default: `claude-sonnet-4-20250514`). |
| **codex** | OpenAI Codex CLI | Set `PLAN_AN_GO_CODEX_MODEL` in `.env` (e.g. `codex-20250301`). Empty = CLI default. |
| **cursor-agent** | Cursor agent CLI | Model is chosen by the agent; no env override. |

**How to change the model**

1. **Claude:** In `.env`, set `PLAN_AN_GO_CLAUDE_MODEL=claude-sonnet-4-20250514` (or another model ID from Anthropic).
2. **Codex:** In `.env`, set `PLAN_AN_GO_CODEX_MODEL=codex-20250301` (or your Codex model). Leave empty to use the Codex CLI default.
3. **cursor-agent:** No env var; the agent uses its configured model.
4. **Override per run:** Use `--cli-flags "--model <model-id>"` when your CLI supports it (e.g. `--cli claude --cli-flags "--model claude-3-5-sonnet-20241022"`).

## Environment

Full reference (all keys, defaults, examples): **[docs/ENV-README.md](docs/ENV-README.md)**. That doc also covers **output directory** (`--out-dir`) and **cleanup** (`--clean-after --force`). Summary:

| Variable | Description |
|----------|-------------|
| `PLAN_FILE` | Plan file path (default: `PLAN.md`). |
| `PLAN_AN_GO_CLI` | CLI: `claude`, `codex`, or `cursor-agent`. |
| `PLAN_AN_GO_CLI_FLAGS` | Extra flags passed to the CLI (shared). Use `PLAN_AN_GO_CLAUDE_FLAGS` / `PLAN_AN_GO_CODEX_FLAGS` for per-CLI flags when unset. |
| `PLAN_AN_GO_CLAUDE_MODEL` | Claude model ID (see [Supported CLIs and models](#supported-clis-and-models)). |
| `PLAN_AN_GO_CODEX_MODEL` | Codex model ID (optional). |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | Optional; if set, auth uses the key instead of web login. |
| `USE_SLACK` | Slack is off by default; set to `true` or use `--slack-enable` to enable. If tokens are unset or a post fails, we warn and continue (no exit). |
| `PLAN_AN_GO_ROOT` | Default operating/root path for the `scripts/plan-an-go` entry script. If unset, root is the directory containing `scripts/` or `--root` on the CLI. |
| `PLAN_AN_GO_SLACK_*` | Slack app tokens; see [docs/ENV-README.md](docs/ENV-README.md) and `.env.sample`. |

## Examples

**npm (from repo root):**

```bash
npm run plan-an-go
npm run plan-an-go-forever
npm run plan-an-go-forever -- --concurrency 3
npm run plan-an-go-validate -- <implementer_output_file>
npm run example:count
npm run check
```

**More examples (from repo root; pass args after `--`):**

```bash
npm run plan-an-go-forever -- 100 10 --plan PLAN.md --cli codex --no-slack --tail
npm run plan-an-go-forever -- 100 10 --plan PLAN.md --cli claude --no-slack
npm run plan-an-go-forever -- 5 25 --workspace ./examples/count --plan PLAN.md --no-slack
npm run plan-an-go-forever -- 50 50 --concurrency 3 --no-slack
npm run plan-an-go-task-watcher -- --plan PLAN.md
npm run plan-an-go-validate -- /path/to/implementer-output.txt --workspace . --cli codex
```

**Concurrency (multiple agents in parallel):**

```bash
npm run plan-an-go-forever -- --concurrency 3 --no-slack
npm run plan-an-go-forever -- 100 50 --concurrency 2 --plan PLAN.md --cli claude
```

Run the task watcher in another terminal to see in-progress tasks with a yellow ● and agent id (e.g. `AGENT_01`, `AGENT_02`).

### Example: count

The [examples/count](examples/count) folder contains a minimal plan that writes the numbers 1–10 to `./test.txt` in that folder. Use it to verify your setup.

```bash
npm run example:count
```

- Prints the **log file path** at the top (e.g. `examples/count/run-20260303-120000.log`).
- Streams pipeline output to the terminal and appends it to that file.
- Uses 5 parent loops, 25 child loops, `--no-slack`, and runs with `--workspace examples/count` and `--plan PLAN.md`.

See [examples/count/README.md](examples/count/README.md) for details.

## Project layout

- `scripts/plan-an-go` — **Entry script** (globally runnable via `npm run` or `plan-an-go` after `npm link` / `npm i -g`). Resolves operating root from `--root`, `.env` `PLAN_AN_GO_ROOT`, or the directory containing `scripts/`; then runs subcommands (`run`, `forever`, `validate`, `task-watcher`, `planner`, `prd`, `reset`, `setup`, etc.). Run `./scripts/plan-an-go help` for usage.
- `scripts/system/` — Setup: `setup.sh`, `install-clis.sh`, `auth-cli.sh`, `verify.sh` (see `scripts/system/README.md`). Use via npm: `npm run setup`, `npm run install-clis`, `npm run auth-cli`, `npm run verify`.
- `scripts/cli/` — CLI entrypoints: `plan-an-go.sh`, `plan-an-go-forever.sh`, `plan-an-go-validate.sh`, task-watcher, Slack; see `scripts/cli/README.md`.
- `examples/count/` — Minimal runnable example; `npm run example:count`.
- `assets/prompts/` — Optional prompt templates (scripts build prompts inline by default).
- `MAKEFILE` — Convenience targets (run, validate, planner, prd, lint, format, check, setup, etc.); run `make -f MAKEFILE` for the full list.

## License and contributors

- **License:** [LICENSE](LICENSE) (MIT). Use, modify, and distribute with attribution.
- **Changelog:** [CHANGELOG.md](CHANGELOG.md) for version history and what's new.
- **Contributors:** [CONTRIBUTORS.md](CONTRIBUTORS.md).
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and how to report issues or open PRs.

### Publishing (maintainers)

To publish to npm: run tests and checks, bump version in `package.json`, then `npm publish`. Only paths listed in `package.json` `files` (and not excluded by `.npmignore`) are included. Ensure the repo is pushed and the GitHub release (if any) matches the npm version.
