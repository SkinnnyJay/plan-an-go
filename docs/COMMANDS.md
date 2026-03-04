# Command reference

Full argument tables, examples, and when to use each command. Run everything from **plan-an-go repo root** via npm; pass extra arguments after `--`.

See also: [Environment variables](ENV-README.md), [README](../README.md) (Quick start, examples).

---

## Output directory and plan path

### Where is code created when no output is set?

If you **do not** pass `--out-dir` (or `--workspace`), the workspace defaults to **plan-an-go’s root** (the directory containing `scripts/`, or `PLAN_AN_GO_ROOT` from `.env`, or `--root`). The implementer creates and modifies code **in that directory**. The plan used is `./PLAN.md` there.

### Using `--out-dir`

| Effect | Description |
|--------|-------------|
| **run / forever** | Workspace = `DIR`. Implementer runs in `DIR`; plan = `DIR/PLAN.md` unless you pass `--plan`. |
| **planner** | Writes `DIR/PLAN.md` (unless you pass `--out`). |
| **prd** | Writes `DIR/PRD.md` (unless you pass `--out`). |

Directory is created if missing. Use **unique dirs per project** (e.g. `./tmp/todo-tmp`, `./examples/todo`) so runs don’t overwrite each other.

### Overriding the plan

You can set the output dir **and** use a different plan file:

- **`--out-dir DIR`** — Where to build (workspace).
- **`--plan PATH`** — Which plan file to use. If `PATH` is relative, it is resolved relative to the workspace.

Examples:

```bash
# Build in tmp/todo-tmp, use plan from another path (relative to repo root)
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --plan examples/todo/PLAN.md --no-slack

# Build in tmp/todo-tmp, use plan in a subfolder of that workspace
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --plan plans/main.PLAN.md --no-slack
```

### Generating PLAN from PRD in a folder

To generate `PLAN.md` from a PRD that lives in the same folder (e.g. for an example):

```bash
npm run plan-an-go-planner -- --out-dir examples/todo --in examples/todo/PRD.md
```

This writes `examples/todo/PLAN.md` and uses `examples/todo/PRD.md` as input.

---

## plan-an-go-forever (orchestrator)

Runs **implementer → validator** in a loop until all tasks are complete or max iterations.

**Usage:** `npm run plan-an-go-forever -- [parent_loops] [child_loops] [options]`

### Arguments

| Argument | Description |
|----------|-------------|
| `parent_loops` | Number of orchestrator iterations (default: 100). |
| `child_loops` | Max LLM calls per agent per iteration (default: 50). |
| `--out-dir DIR` | Use DIR as workspace; plan = `DIR/PLAN.md` unless `--plan` is set. |
| `--workspace DIR` | Run from DIR (same idea as `--out-dir` when using entry script). |
| `--plan FILE` | Plan file (default: `PLAN.md`; relative to workspace if not absolute). |
| `--no-validate` | Skip validator; implementer only. |
| `--no-slack` | Disable Slack (default). |
| `--slack-enable` | Enable Slack (requires tokens in `.env`). |
| `--stream` | Stream LLM output in real time. |
| `--tail` | Write iteration output to `./tmp/pipeline-tail.log` (or `--tail=FILE`). |
| `--verbose` | Full iteration summaries and plan-check output. |
| `--quiet` | Only header, errors, and final result. |
| `--concurrency N` | Run N implementer agents in parallel. |
| `--cli NAME` | `claude`, `codex`, or `cursor-agent`. |
| `--cli-flags "FLAGS"` | Extra flags for the CLI. |
| `--strict` | Require plan to be `<work>`-compliant; exit 1 if not. |
| `--clean-after` | After exit, remove workspace contents. **Requires `--force`**; only when workspace is a subdir of repo. |
| `--force` | Required with `--clean-after`. |

### Examples

```bash
# Simple: build in tmp/todo-tmp, no Slack
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --no-slack

# Custom loops and workspace
npm run plan-an-go-forever -- 50 25 --out-dir tmp/todo-tmp --no-slack

# Override plan path
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --plan examples/todo/PLAN.md --no-slack

# Multiple agents in parallel
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --concurrency 3 --no-slack

# Stream output and tail log
npm run plan-an-go-forever -- --out-dir tmp/todo-tmp --stream --tail --no-slack
```

### When to use

- Default way to run the full pipeline until the plan is done.
- Use `--out-dir` to build in a dedicated folder (e.g. `tmp/todo-tmp`, `examples/todo`) so the plan-an-go repo stays clean.
- Use `--concurrency N` when you want multiple tasks worked on in parallel.

---

## plan-an-go (implementer, one cycle)

Runs **one** implementer cycle: pick the first incomplete task, implement it, update the plan.

**Usage:** `npm run plan-an-go -- [options]`

### Arguments

| Argument | Description |
|----------|-------------|
| `--out-dir DIR` | Use DIR as workspace; plan = `DIR/PLAN.md` unless `--plan` set. |
| `--workspace DIR` | Run from DIR. |
| `--plan FILE` | Plan file (default: `PLAN.md`). |
| `--cli NAME` | `claude`, `codex`, or `cursor-agent`. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |
| `--strict` | Require plan to be `<work>`-compliant. |

### Examples

```bash
# One cycle in default workspace (repo root)
npm run plan-an-go

# One cycle in a specific folder
npm run plan-an-go -- --out-dir tmp/todo-tmp
```

### When to use

- To test a single task or debug the implementer.
- For a quick “one task” run without starting the full forever loop.

---

## plan-an-go-validate (validator)

Runs the validator on a **saved implementer output file** (e.g. a log from a previous run).

**Usage:** `npm run plan-an-go-validate -- <implementer_output_file> [options]`

### Arguments

| Argument | Description |
|----------|-------------|
| `implementer_output_file` | Path to saved implementer stdout (required). |
| `--workspace DIR` | Run from DIR. |
| `--cli NAME` | Same as implementer. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |

### Examples

```bash
npm run plan-an-go-validate -- ./tmp/8cc8fbc8/forever-impl.XXXXXX
npm run plan-an-go-validate -- ./tmp/implementer-output.log --workspace tmp/todo-tmp
```

### When to use

- To re-run validation on a past implementer run without re-running the implementer.
- To audit whether a given output would pass the validator.

---

## plan-an-go-planner (generate PLAN)

Generates a **PLAN.md** from a PRD file or a freeform prompt.

**Usage:** `npm run plan-an-go-planner -- [options] [input_file]`

### Arguments

| Argument | Description |
|----------|-------------|
| `--in PATH` | Input file (PRD or other doc to plan from). |
| `--out PATH` | Output file (default: `./PLAN.md`). With `--out-dir DIR`, default becomes `DIR/PLAN.md`. |
| `--out-dir DIR` | Write `DIR/PLAN.md` unless `--out` is set. |
| `--prompt="..."` | Use this string as input instead of a file. |
| `--task-detail L\|M\|H\|XH` | Task granularity: **L** (low), **M** (medium, default), **H** (high), **XH** (extra high). |
| `--cli NAME` | `claude`, `codex`, or `cursor-agent`. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |

Positional: if you don’t use `--prompt` or `--in`, you can pass the input file as a positional argument (e.g. `PRD.md`).

### Examples

```bash
# Generate PLAN from PRD in the same folder (e.g. for an example)
npm run plan-an-go-planner -- --out-dir examples/todo --in examples/todo/PRD.md

# From a prompt, write to a specific path
npm run plan-an-go-planner -- --prompt="Todo app with CRUD and filters" --out ./tmp/todo-tmp/PLAN.md

# Extra-high task granularity
npm run plan-an-go-planner -- --task-detail XH --out-dir examples/todo --in examples/todo/PRD.md
```

### When to use

- After writing or updating a PRD: generate the plan that the implementer will follow.
- To create a plan from a short prompt when you don’t have a PRD.

---

## plan-an-go-prd (generate PRD)

Generates a structured **PRD** from a freeform prompt or an input document.

**Usage:** `npm run plan-an-go-prd -- [options]`

### Arguments

| Argument | Description |
|----------|-------------|
| `--prompt="..."` | Use this string as input (product/feature description). |
| `--in PATH` | Input file to expand or structure as a PRD. |
| `--out PATH` | Output file (default: `./PRD.md`). With `--out-dir DIR`, default becomes `DIR/PRD.md`. |
| `--out-dir DIR` | Write `DIR/PRD.md` unless `--out` is set. |
| `--cli NAME` | Same as planner. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |

### Examples

```bash
# PRD from prompt into a folder
npm run plan-an-go-prd -- --out-dir examples/todo --prompt="Todo app with shadcn/ui and Prisma"

# PRD from existing notes
npm run plan-an-go-prd -- --in notes.md --out ./PRD.md
```

### When to use

- Start a new product or feature: get a structured PRD, then pass it to the planner to get a PLAN.

---

## plan-an-go-prd-from-plan (PRD from PLAN)

Validates, corrects, or **generates a PRD** from an existing PLAN (file or string).

**Usage:** `npm run plan-an-go-prd-from-plan -- [options] [plan_file]`

### Arguments

| Argument | Description |
|----------|-------------|
| `--plan PATH` | PLAN file. |
| `--plan-string "..."` | PLAN content as string (no file). |
| `--prd PATH` / `--out PATH` | Output PRD path (default: `./PRD.md`). With `--out-dir DIR`, default becomes `DIR/PRD.md`. |
| `--out-dir DIR` | Write `DIR/PRD.md` unless `--prd`/`--out` is set. |
| `--cli NAME` | Same as planner. |
| `--cli-flags "FLAGS"` | Extra CLI flags. |

### Examples

```bash
npm run plan-an-go-prd-from-plan -- --plan examples/todo/PLAN.md --prd examples/todo/PRD.md
npm run plan-an-go-prd-from-plan -- --out-dir examples/todo --plan examples/todo/PLAN.md
```

### When to use

- You have a PLAN and want a PRD that matches it (for docs or to re-plan later).
- To fix or standardize an existing PRD so it aligns with the PLAN.

---

## plan-an-go-task-watcher / task:watcher (live task list)

Shows a live view of the plan’s tasks. **Full** list or **minimal** (context around incomplete only).

**Usage:**

```bash
npm run plan-an-go-task-watcher -- [options]   # full list
npm run task:watcher -- [options]              # minimal (5 before/5 after incomplete)
```

### Arguments

| Argument | Description |
|----------|-------------|
| `--plan PATH` | Plan file (default: `./PLAN.md`). |
| `--once` | Single run, no file watch. |
| `--minimal` | Show context around incomplete tasks only. |
| `--minimal-before N` | In minimal mode: N completed tasks before first incomplete (default: 3; task:watcher uses 5). |
| `--minimal-after N` | In minimal mode: N completed tasks after last incomplete (default: 3; task:watcher uses 5). |
| `--width N` | Terminal width for truncation. |
| `--max-rows N` | Max task rows. |
| `--ids-only` | Show only ID and checkmark. |
| `--no-progress` | Hide progress bar. |
| `--no-color` | Disable color. |
| `--poll N` | fswatch poll interval (seconds). |

Requires `fswatch` for watch mode (`brew install fswatch`).

### Examples

```bash
npm run plan-an-go-task-watcher -- --plan tmp/todo-tmp/PLAN.md
npm run task:watcher -- --plan examples/todo/PLAN.md
```

### When to use

- Run in a second terminal while `plan-an-go-forever` is running to see task progress.
- With `--concurrency N`, in-progress tasks show a yellow ● and agent id (e.g. AGENT_01).

---

## reset (reset completed tasks)

Resets completed tasks from `[x]` to `[ ]` in a plan file.

**Usage:** `npm run reset -- [options]` or `npm run plan-an-go-reset -- [options]`

### Arguments

| Argument | Description |
|----------|-------------|
| `--plan FILE` | Plan file (default: `./PLAN.md`). |
| `--milestone N` / `-m N` | Only reset tasks in milestone N (e.g. 1 for M1:1, M1:2, …). |
| `--force` | Do not create a `.bak` backup before modifying. |

By default, creates `<plan>.bak` before changing the file.

### Examples

```bash
npm run reset -- --plan tmp/todo-tmp/PLAN.md
npm run reset -- --plan examples/todo/PLAN.md --milestone 1
npm run reset -- --plan PLAN.md --force
```

### When to use

- After changing the plan or the app and you want to re-run the pipeline from scratch or from a given milestone.
- To redo only one milestone with `--milestone N`.

---

## plan-an-go-plan-check (plan health check)

Checks that a plan file exists, is non-empty, and (optionally) is `<work>`-compliant. Reports milestone/task counts, completion progress, and formatting issues. Used by the orchestrator and planner; you can run it manually to validate a plan before running the pipeline.

**Usage:** `./scripts/cli/plan-an-go-plan-check.sh [--strict] [plan_file]`  
From repo root. No npm script; use the script path or `make -f MAKEFILE plan-check FILE=path [STRICT=1]`.

### Arguments

| Argument | Description |
|----------|-------------|
| `--strict` | Require plan to be `<work>`-compliant (at least one `<work>...</work>` block with at least one task line). Exit 1 if not. |
| `plan_file` | Plan file path (default: `PLAN.md`). Resolved relative to current directory. |

Without `--strict`, a non-compliant plan prints a warning but still reports counts (which may include prompt/example text). With `--strict`, the script exits 1 and does not continue.

### Examples

```bash
# From repo root
./scripts/cli/plan-an-go-plan-check.sh PLAN.md
./scripts/cli/plan-an-go-plan-check.sh --strict examples/todo/PLAN.md

# Via Make (use STRICT=1 to require <work>)
make -f MAKEFILE plan-check FILE=PLAN.md
make -f MAKEFILE plan-check FILE=examples/todo/PLAN.md STRICT=1
```

### When to use

- Before running the pipeline, to confirm the plan has the expected structure and task counts.
- With `--strict` in CI or scripts to enforce `<work>...</work>` so only real tasks are parsed.
- After generating a plan with the planner (the planner runs plan-check on the output when the script is present).

---

## Other commands (summary)

| Command | Description |
|---------|-------------|
| `npm run plan-an-go-onboard` | Interactive onboarding: env review, then menu (setup, run, forever, prd, planner, wizard, validate, task-watcher, reset, help). |
| `npm run plan-an-go-wizard` | Guided flow: PRD → review → update → validate → write → launch. |
| `./scripts/cli/plan-an-go-plan-check.sh [--strict] [file]` | Plan health check (counts, compliance). Use `--strict` to require `<work>`. Or `make -f MAKEFILE plan-check FILE=path [STRICT=1]`. |
| `npm run setup` | One-shot system setup (install CLIs + auth + verify). |
| `npm run install-clis [-- all]` | Install CLIs. |
| `npm run auth-cli [-- all]` | Authenticate CLIs. |
| `npm run verify [-- --force]` | Verify CLIs/keys. |

Full environment variable reference: [ENV-README.md](ENV-README.md).
