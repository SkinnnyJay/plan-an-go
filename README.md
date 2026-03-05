<img src="./assets/images/readme-header.png" alt="plan-an-go - Orchestrate Your CLI Workflows" width="100%;" />

# plan-an-go

Automated **implement → validate** pipeline driven by a plan file (e.g. `PLAN.md`). An orchestrator runs an Implementation Agent and a Validation Agent in a loop until all tasks are done or you stop it. **BYOC** — Bring Your Own CLI: use **Claude**, **Codex**, **Cursor**, **Gemini**, or any CLI you prefer.

---

## Table of contents

| Section | Description |
|---------|-------------|
| [Features](#features) | What plan-an-go does |
| [Install](#install) | npm (global/project) or from source |
| [System setup](#system-setup) | Install CLIs, auth, verify |
| [First-time use](#first-time-use) | Step-by-step for new users |
| [Quick start](#quick-start) | Create a plan, configure, run |
| [Plan compliance](#plan-compliance-work-and--strict) | `<work>` blocks and `--strict` |
| [Full flow walkthrough](#full-flow-walkthrough) | End-to-end todo app example |
| [Commands](#commands) | Command summary and links |
| [Script arguments](#script-arguments-quick-reference) | Quick reference; full details in docs |
| [Supported CLIs and models](#supported-clis-and-models) | Claude, Codex, Cursor |
| [Environment](#environment) | Key variables; full reference in docs |
| [Examples](#examples) | count, todo, journal, and more |
| [Project layout](#project-layout) | Repo structure |
| [Documentation](#documentation) | Full docs index (extendable) |
| [License and contributors](#license-and-contributors) | License, changelog, contributing |

---

## Features

| Feature | Description |
|---------|-------------|
| **Implement → validate loop** | One agent implements tasks from your plan; another validates. Loop runs until every task is done or you stop it. |
| **Multiple CLIs** | Use **Claude**, **Codex**, or **Cursor**. Set default in `.env` or pass `--cli` per run. |
| **Plan from prompt or PRD** | Generate `PLAN.md` from a short prompt or from a PRD; generate PRDs from prompts. Templates use `<work>...</work>` so only real tasks are parsed. |
| **Concurrent agents** | Run several implementers in parallel with `--concurrency N`; each agent gets its own task. Optional live **task watcher** (full or minimal list). |
| **Optional Slack** | Post progress to a Slack channel (or thread); off by default. |
| **Strict mode** | Require plans to wrap milestones and tasks in `<work>...</work>` with `--strict` so prompt/example text is never counted as tasks. |

---

## Install

Choose one option:

### From npm (global)

```bash
npm install -g plan-an-go
```

Then run `plan-an-go` from any directory. Copy `.env.sample` from the package (e.g. `$(npm root -g)/plan-an-go/.env.sample`) to your config location, rename to `.env`, and set `PLAN_AN_GO_ROOT` to your project directory (or pass `--root /path/to/project` when you run commands).

### From npm (project)

```bash
npm install plan-an-go
```

Use via `npx plan-an-go` or `npm run` scripts. Put `.env` in the project root and set `PLAN_AN_GO_ROOT` to that path if needed.

### From source

Clone the repo, then from repo root:

```bash
cp .env.sample .env
npm run plan-an-go          # one cycle
npm run plan-an-go-forever  # continuous loop
```

See [Quick start](#quick-start) for details.

---

## System setup

Before running the pipeline, install the CLI you'll use and authenticate it.

### One-shot setup

From repo root:

```bash
npm run setup
```

Interactive: install CLIs, authenticate, verify. To install everything: `npm run setup -- all`.

### Step-by-step

| Step | Command | Notes |
|------|---------|--------|
| Install CLIs | `npm run install-clis` or `npm run install-clis -- all` | Interactive, or list: `claude`, `codex`, `jq`, `fswatch`, `cursor-agent` |
| Authenticate | `npm run auth-cli` or `npm run auth-cli -- all` | Web login unless `PLAN_AN_GO_ANTHROPIC_API_KEY` or `PLAN_AN_GO_OPENAI_API_KEY` set in `.env`. Log out: `npm run auth-cli -- --logout` |
| Verify | `npm run verify` | Fails on missing CLIs/keys. Use `npm run verify -- --force` to warn but exit 0 |

### Onboarding menu

```bash
npm run plan-an-go-onboard
```

Interactive menu: review or set key variables (from `.env` or defaults), then choose an action (setup, run, forever, prd, planner, wizard, validate, task-watcher, reset, or help).

### Tip

Set the default CLI in `.env`: `PLAN_AN_GO_CLI=claude` (or `codex`, `cursor-agent`) so you don't need to pass `--cli` each time.

### Platforms

`install-clis` supports **macOS** (darwin), **Linux**, and **Windows** (Git Bash / MSYS2 / Cygwin) via `scripts/system/install-clis-<platform>.sh`. See [scripts/system/README.md](scripts/system/README.md) for details.

---

## First-time use

If you're new to plan-an-go, follow these steps to confirm everything works.

### Step 1 — Install (from source)

Clone the repo, then from repo root:

```bash
cp .env.sample .env
```

Edit `.env` if you want (e.g. `PLAN_AN_GO_CLI=claude` or `codex` or `cursor-agent`).

### Step 2 — Setup CLIs and auth

```bash
npm run setup
```

Pick the CLI(s) to install and authenticate. Or step-by-step: `npm run install-clis`, then `npm run auth-cli`.

### Step 3 — Verify

```bash
npm run verify
```

Ensures your chosen CLI and keys are present.

### Step 4 — Run the count example

Minimal plan that writes 1–10 to a log file. From repo root:

```bash
npm run example:count
```

You'll see the **log file path** at the top, then streamed output. When it finishes, your setup is working.

### Step 5 — Optional: onboarding menu

```bash
npm run plan-an-go-onboard
```

Review env and run other commands from the menu.

---

Then use [Quick start](#quick-start) for your own `PLAN.md`, or try one of the [Examples](#examples) (e.g. todo, journal); each has its own README with exact commands.

---

## Quick start

### 1. Create a plan

Add a `PLAN.md` in the repo root with checklist tasks (`[ ]` / `[x]`).

### 2. Configure env

Copy `.env.sample` to `.env` and set `PLAN_AN_GO_CLI` (e.g. `claude`, `codex`, `cursor-agent`). See [Environment variables](docs/ENV-README.md) for all keys and defaults.

### 3. Run

From repo root:

| Goal | Command |
|------|---------|
| One iteration | `npm run plan-an-go` |
| Continuous loop | `npm run plan-an-go-forever` |
| Validate only | `npm run plan-an-go-validate -- <implementer_output_file>` |

---

## Plan compliance (`<work>` and `--strict`)

Plans should wrap **all milestones and task lines** in one or more `<work>...</work>` blocks. Only those blocks are parsed for tasks; prompt text or examples elsewhere are ignored. Multiple `<work>...</work>` chunks are combined. The planner and templates emit this format.

### Without `<work>`

Scripts still run but may match prompt/example lines as tasks; you'll see a **warning**.

### With `--strict`

Require a compliant plan. Use with `forever`, `run`, or `plan-check`. Non-compliant plans exit with an error.

```bash
npm run plan-an-go-forever -- --out-dir ./example/todo --strict --no-slack
./scripts/cli/plan-an-go-plan-check.sh --strict PLAN.md
# or: make -f MAKEFILE plan-check FILE=PLAN.md STRICT=1
```

### Env

`PLAN_AN_GO_STRICT=true` has the same effect as `--strict` for the implementer.

---

## Full flow walkthrough

End-to-end example: **a fully functional todo list app** in modern React with Next.js and Tailwind, using **in-memory storage** (no database).

---

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

Optional: in another terminal, run the task watcher to see progress (full list or minimal with 5 before/5 after incomplete):

```bash
npm run plan-an-go-task-watcher -- --plan ./my-todo-app/PLAN.md
npm run task:watcher -- --plan ./my-todo-app/PLAN.md
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

---

## Commands

Full argument tables, examples, and when to use each command: **[docs/COMMANDS.md](docs/COMMANDS.md)**. Covers output with/without `--out-dir`, plan override `--plan`, and generating PLAN from a PRD.

### Command table

| Command | Description |
|--------|-------------|
| `npm run plan-an-go` | Run one implementer cycle (one task from plan). |
| `npm run plan-an-go-forever` | Run implementer → validator in a loop (default 100 parent × 50 child). |
| `npm run plan-an-go-validate -- <file>` | Run validator on a saved implementer output file. |
| `npm run plan-an-go-task-watcher` | Live task list (full); pass `--plan PATH` etc. after `--`. |
| `npm run plan-an-go-task-watcher-minimal` | Live task list (minimal: 5 tasks before/after incomplete); same args after `--`. |
| `npm run task:watcher` | Same as `plan-an-go-task-watcher-minimal`; pass `--plan PATH` etc. after `--`. |
| `npm run plan-an-go-planner` | Generate a plan from a prompt or PRD; pass `--prompt`, `--out`, `--cli` after `--`. |
| `npm run plan-an-go-prd` | Generate a PRD from a prompt or input doc; pass `--prompt`, `--in`, `--out`, `--cli` after `--`. |
| `npm run reset [-- --plan FILE] [-- --milestone N] [-- --force]` | Reset completed tasks `[x]` → `[ ]` in a plan; optional milestone; default backup is `<plan>.bak`. |
| `npm run plan-an-go-onboard` | Interactive onboarding: optional env review (from `.env`/defaults), then menu to run setup, run, forever, prd, planner, wizard, validate, task-watcher, reset, or help. |
| `npm run example:count` | Run the [count example](#example-count) — prints log path at top, then streams output. |
| `npm run setup` | One-shot system setup (install CLIs + auth + verify). |
| `npm run install-clis [-- all]` | Install CLIs (interactive or `all`). |
| `npm run auth-cli [-- all]` | Authenticate CLIs. |
| `npm run verify [-- --force]` | Verify CLIs/keys; `--force` warns but exits 0. |
| `npm run lint` | Run ShellCheck on scripts. |
| `npm run lint:sh` | ShellCheck only (scripts and entry). |
| `npm run format` | Check shell script formatting (shfmt; requires `shfmt` installed). |
| `npm run format:write` | Fix shell script formatting. |
| `npm run check` | Lint + format check (run before commits). |
| `npm run ci` / `npm run build` | Full gate for local pre-commit: lint → format check → test. GitHub CI runs only lint+format (tests require local CLIs). |

### Linting and formatting

- Install [ShellCheck](https://github.com/koalaman/shellcheck) and [shfmt](https://github.com/mvdan/sh) (e.g. `brew install shellcheck shfmt` on macOS).
- Run: `npm run lint`, `npm run format`, `npm run format:write`, `npm run check`. Same via Make: `make lint`, `make format`, `make format-write`, `make check`.
- Repo uses `.shellcheckrc` and shfmt `-i 2 -ci`. GitHub CI runs only `npm run check`. Run `npm run ci` or `make ci` (alias `make build`) locally before commit for the full gate including tests (requires local CLIs).

---

## Script arguments (quick reference)

All scripts run from **repo root** via npm; pass extra args after `--`. Full details: **[docs/COMMANDS.md](docs/COMMANDS.md)**.

### By script

| Script | Key arguments |
|--------|----------------|
| **plan-an-go-forever** | `[parent_loops] [child_loops]`, `--out-dir`, `--plan`, `--no-slack`, `--concurrency`, `--stream`, `--tail` |
| **plan-an-go** | One implementer cycle; `--out-dir`, `--plan`, `--cli` |
| **plan-an-go-validate** | `npm run plan-an-go-validate -- <file>`; optional `--workspace`, `--cli` |
| **plan-an-go-planner** | `--in`, `--out`, `--out-dir`, `--prompt`, `--task-detail L,M,H,XH` |
| **plan-an-go-prd** | `--prompt`, `--in`, `--out`, `--out-dir` |
| **plan-an-go-prd-from-plan** | `--plan`, `--prd`/`--out`, `--out-dir` |
| **plan-an-go-task-watcher** / **task:watcher** | `--plan`, `--minimal`, `--once`; requires `fswatch` |
| **plan-an-go-plan-check** | `./scripts/cli/plan-an-go-plan-check.sh [--strict] [plan_file]`; see [docs/COMMANDS.md](docs/COMMANDS.md) |
| **reset** | `--plan`, `--milestone N`, `--force`; creates `.bak` by default |

---

## Supported CLIs and models

### CLI table

| CLI | Description | Model selection |
|-----|-------------|------------------|
| **claude** | Anthropic Claude CLI | Set `PLAN_AN_GO_CLAUDE_MODEL` in `.env` (default: `claude-sonnet-4-20250514`). |
| **codex** | OpenAI Codex CLI | Set `PLAN_AN_GO_CODEX_MODEL` in `.env` (e.g. `codex-20250301`). Empty = CLI default. |
| **cursor-agent** | Cursor agent CLI | Model is chosen by the agent; no env override. |

### How to change the model

| CLI | In `.env` | Per run |
|-----|-----------|---------|
| **Claude** | `PLAN_AN_GO_CLAUDE_MODEL=claude-sonnet-4-20250514` (or other Anthropic model ID) | `--cli-flags "--model <model-id>"` |
| **Codex** | `PLAN_AN_GO_CODEX_MODEL=codex-20250301` (or leave empty for CLI default) | Same |
| **cursor-agent** | No env var; agent uses its configured model | — |

---

## Environment

Full reference (all keys, defaults, examples): **[docs/ENV-README.md](docs/ENV-README.md)**. Also covers **output directory** (`--out-dir`) and **cleanup** (`--clean-after --force`).

### Quick reference

| Variable | Description |
|----------|-------------|
| `PLAN_FILE` | Plan file path (default: `PLAN.md`). |
| `PLAN_AN_GO_CLI` | CLI: `claude`, `codex`, or `cursor-agent`. |
| `PLAN_AN_GO_CLI_FLAGS` | Extra flags passed to the CLI (shared). Use `PLAN_AN_GO_CLAUDE_FLAGS` / `PLAN_AN_GO_CODEX_FLAGS` for per-CLI flags when unset. |
| `PLAN_AN_GO_CLAUDE_MODEL` | Claude model ID (see [Supported CLIs and models](#supported-clis-and-models)). |
| `PLAN_AN_GO_CODEX_MODEL` | Codex model ID (optional). |
| `PLAN_AN_GO_ANTHROPIC_API_KEY` / `PLAN_AN_GO_OPENAI_API_KEY` | Optional; if set, auth uses the key instead of web login. |
| `PLAN_AN_GO_USE_SLACK` | Slack is off by default; set to `true` or use `--slack-enable` to enable. If tokens are unset or a post fails, we warn and continue (no exit). |
| `PLAN_AN_GO_ROOT` | Default operating/root path for the `scripts/plan-an-go` entry script. If unset, root is the directory containing `scripts/` or `--root` on the CLI. |
| `PLAN_AN_GO_SLACK_*` | Slack app tokens; see [docs/ENV-README.md](docs/ENV-README.md) (includes [Setting up Slack for pipeline updates](docs/ENV-README.md#setting-up-slack-for-pipeline-updates)) and `.env.sample`. |

---

## Examples

Each example has its own README with step-by-step commands. Run from **repo root** unless noted.

### Example table

| Example | Description | How to run |
|--------|-------------|------------|
| **[count](examples/count/README.md)** | Minimal: writes 1–10 to a log file. Use to **verify setup** after first-time install. | `npm run example:count` or `./examples/count/run.sh` |
| **[todo](examples/todo/README.md)** | Todo list web app (React, Next.js, TypeScript, Prisma, SQLite, shadcn/ui). PRD → plan → implement loop. | `./examples/todo/run.sh` or planner + forever with `--out-dir ./examples/todo` |
| **[journal](examples/journal/README.md)** | Personal journal app (entries, tags, search, markdown, shadcn/ui). | `./examples/journal/run.sh` or planner + forever with `--out-dir ./examples/journal` |
| **[vacation-airbnb](examples/vacation-airbnb/README.md)** | Vacation-planning TODO app with Airbnb integration. | `./examples/vacation-airbnb/run.sh` or planner + forever with `--out-dir ./examples/vacation-airbnb` |
| **[youtube-clone](examples/youtube-clone/README.md)** | YouTube-style app (search, embed playback, watch later, playlists). | `./examples/youtube-clone/run.sh` or planner + forever with `--out-dir ./examples/youtube-clone` |

**Count** is the only example that doesn't need a PRD or generated plan; its `PLAN.md` is checked in. The others use a PRD and generate `PLAN.md` via the planner (or the example's `run.sh`). See each example's README for details.

### Command snippets

From repo root; pass extra args after `--`:

```bash
# One run, loop, validate, count example
npm run plan-an-go
npm run plan-an-go-forever
npm run plan-an-go-forever -- --concurrency 3
npm run plan-an-go-validate -- <implementer_output_file>
npm run example:count

# Forever with options
npm run plan-an-go-forever -- 100 10 --plan PLAN.md --cli codex --no-slack --tail
npm run plan-an-go-forever -- 50 50 --concurrency 3 --no-slack
npm run plan-an-go-task-watcher -- --plan PLAN.md
npm run task:watcher -- --plan PLAN.md
```

Run the task watcher in another terminal to see in-progress tasks (yellow ● and agent id, e.g. `AGENT_01`, `AGENT_02`).

### Example: count

Minimal plan that writes 1–10 to `./test.log`. Use to verify setup:

```bash
npm run example:count
```

Prints the log path at the top, then streams output. See [examples/count/README.md](examples/count/README.md) for details.

---

## Project layout

### Directory map

| Path | Description |
|------|-------------|
| `scripts/plan-an-go` | **Entry script** (globally runnable via `npm run` or `plan-an-go` after `npm link` / `npm i -g`). Resolves operating root from `--root`, `.env` `PLAN_AN_GO_ROOT`, or the directory containing `scripts/`; then runs subcommands (`run`, `forever`, `validate`, `task-watcher`, `planner`, `prd`, `reset`, `setup`, etc.). Run `./scripts/plan-an-go help` for usage. |
| `scripts/system/` | Setup: `setup.sh`, `install-clis.sh`, `auth-cli.sh`, `verify.sh` (see `scripts/system/README.md`). Use via npm: `npm run setup`, `npm run install-clis`, `npm run auth-cli`, `npm run verify`. |
| `scripts/cli/` | CLI entrypoints: `plan-an-go.sh`, `plan-an-go-forever.sh`, `plan-an-go-validate.sh`, task-watcher, Slack; see `scripts/cli/README.md`. |
| `examples/count/` | Minimal runnable example; `npm run example:count`. |
| `assets/prompts/` | Optional prompt templates (scripts build prompts inline by default). |
| `MAKEFILE` | Convenience targets (run, validate, planner, prd, lint, format, check, setup, etc.); run `make -f MAKEFILE` for the full list. |

---

## Documentation

Extended docs live in **`docs/`**. Use this index to find details and to add new docs.

### Doc index

| Doc | Contents |
|-----|----------|
| [**docs/README.md**](docs/README.md) | **Documentation index** — table of contents and short descriptions for all docs. Start here to extend or navigate documentation. |
| [**docs/COMMANDS.md**](docs/COMMANDS.md) | **Command reference** — argument tables, examples, and when to use each command (forever, run, validate, planner, prd, prd-from-plan, task-watcher, reset, plan-check). Covers plan compliance (`<work>`, `--strict`), output/workspace (`--out-dir`), plan override (`--plan`), and generating PLAN from PRD. |
| [**docs/ENV-README.md**](docs/ENV-README.md) | **Environment variables** — full table of keys, defaults, and when to set them; output directory and cleanup (`--out-dir`, `--clean-after`, `--force`); [Setting up Slack](docs/ENV-README.md#setting-up-slack-for-pipeline-updates). |

**See also:** [CLAUDE.md](CLAUDE.md) (commands, plan format, architecture), [.env.sample](.env.sample) (copy to `.env`).

---

## License and contributors

### Links

| Link | Description |
|------|--------------|
| [LICENSE](LICENSE) | MIT — use, modify, and distribute with attribution. |
| [CHANGELOG.md](CHANGELOG.md) | Version history and what's new. |
| [CONTRIBUTORS.md](CONTRIBUTORS.md) | Contributors. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup, how to report issues or open PRs. |

### Publishing (maintainers)

To publish to npm: run tests and checks, bump version in `package.json`, then `npm publish`. Only paths listed in `package.json` `files` (and not excluded by `.npmignore`) are included. Ensure the repo is pushed and the GitHub release (if any) matches the npm version.
