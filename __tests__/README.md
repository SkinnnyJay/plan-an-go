# Script tests

Tests for plan-an-go bash scripts. All test output is written only to `./tmp/` (from repo root). Input artifacts (PLAN, PRD, config) live in `__tests__/artifacts/`.

## Test types: smoke vs full

- **Smoke** (default): unit + output + integration tests only. Fast; suitable for pre-commit. **Large tests are never run** unless you explicitly request them. (CI runs only lint/format; tests require local CLIs.)
- **Full**: smoke plus large tests. Run with `--full` or `--large` (or `npm run test:full` / `npm run test:large`). Large tests cover PRD artifacts and optional multi-app creation (planner runs with real CLI when `RUN_LARGE_TESTS=1`). Use for full regression or before release.

## Running

```bash
npm test              # Smoke tests only (same as test:smoke)
npm run test:smoke    # Smoke tests only
npm run test:full     # Full suite including large (multi-app PRD/planner tests)
npm run test:verbose  # Smoke with per-test output and details
npm run test:large    # Same as test:full (backward compatible)
npm run test:journal  # Run only prd-journal.large.test.sh
npm run test:todo-list
npm run test:vacation-airbnb
npm run test:youtube-clone
./__tests__/run-tests.sh [--verbose] [--smoke | --full] [--large] [--test NAME]
```

Run smoke tests locally before commit (`npm test`). CI does not run tests (only lint/format). Use `npm run test:full` or `--full` / `--large` to include large tests. See [artifacts/README.md](artifacts/README.md#large-tests-prd-artifacts).

## Test file format

- Name: `filename.<type>.test.sh` (e.g. `extract-incomplete-tasks.unit.test.sh`, `plan-an-go-reset.integration.test.sh`).
- Each test script must:
  - Write only under `./tmp/`
  - Use `__tests__/artifacts/` for read-only PLAN/PRD/config
  - Exit 0 on success, non-zero on failure
  - Accept optional `--verbose` and print extra info when set
- The runner shows only pass/fail by default; with `--verbose` it shows each test name and full output.

## Tests included

| Test file | Type | What it checks |
|-----------|------|----------------|
| `extract-incomplete-tasks.unit.test.sh` | unit | Extract script output contains only header + incomplete tasks, no `[x]`. |
| `plan-an-go-reset.integration.test.sh` | integration | Reset script converts `[x]` to `[ ]` and reports count; plan under `./tmp/`. |
| `plan-an-go.implementer-output.test.sh` | output | Implementer fail-early: invalid `--cli`, missing plan, empty plan (ERROR/VERDICT in output). |
| `plan-an-go-validate.output.test.sh` | output | Validator fail-early: missing implementer output, invalid `--cli`. |
| `plan-an-go.entry.test.sh` | output | Entry script: `help` and unknown subcommand output. |
| `plan-an-go-planner.output.test.sh` | output | Planner: no input shows Usage; missing input file and invalid `--cli` errors. |
| `plan-an-go-plan-check.output.test.sh` | output | Plan check passes on artifact PLAN; fails on missing file. |
| `plan-an-go-prd.output.test.sh` | output | PRD script: no input shows usage; missing input file and invalid `--cli` errors. |
| `plan-an-go-wizard.output.test.sh` | output | Wizard: `--skip 1` with state runs steps 2–6; step 4 validate (no path, nonexistent file, valid PRD); step 1 prompt required; step 5 no path. |
| `plan-an-go-validate-providers.output.test.sh` | output | Validate CLI wrappers: `plan-an-go-validate-{claude,codex,cursor-agent}.sh` forward to validator and show same error when implementer output is missing. |
| `extract-incomplete-tasks.agent-id.unit.test.sh` | unit | With `AGENT_ID` set, extract outputs only the task line(s) containing `[IN_PROGRESS]:[AGENT_xx]` (sub-agent / concurrency filtering). |
| `plan-an-go-forever.concurrency.unit.test.sh` | unit | Replicates orchestrator marking: first N incomplete tasks get `[IN_PROGRESS]:[AGENT_01]` … `[AGENT_N]`. |
| `plan-an-go-forever.concurrency.integration.test.sh` | integration | **Optional:** Run with `RUN_FOREVER_INTEGRATION=1`. Runs one iteration of `plan-an-go-forever.sh` with `--concurrency 2` and a mock CLI; asserts output mentions 2 agents and tasks. |
| `plan-an-go-forever.output.test.sh` | output | Forever fail-early: invalid `--cli`, missing plan. **Optional (RUN_FOREVER_INTEGRATION=1):** mock run asserts compact header (Plan, Slack, Validation, Stream), iteration line, one-line summary; `--quiet` hides per-iteration lines; `--verbose` shows summary/plan-check. |
| `prd-journal.large.test.sh` | large | PRD-JOURNAL.md artifact exists and structure; optional planner run when `RUN_LARGE_TESTS=1`. |
| `prd-todo-list.large.test.sh` | large | PRD-TODO-LIST.md artifact; optional planner when `RUN_LARGE_TESTS=1`. |
| `prd-vacation-airbnb.large.test.sh` | large | PRD-VACATION-AIRBNB.md artifact; optional planner when `RUN_LARGE_TESTS=1`. |
| `prd-youtube-clone.large.test.sh` | large | PRD-YOUTUBE-CLONE.md artifact; optional planner when `RUN_LARGE_TESTS=1`. |

**Sub-agents / swarm:** The implementer prompt tells the LLM it can delegate to sub-agents (e.g. Cursor `mcp_task`). That behavior is LLM/MCP-side; there are no script-level tests for it. The scripts only pass `PLAN_AN_GO_AGENT_ID` for concurrency and rely on `extract-incomplete-tasks.sh` to filter the plan per agent.

## Adding tests

1. Add `__tests__/<name>.<type>.test.sh` (executable).
2. Use `./tmp/` for all writes; read from `__tests__/artifacts/` as needed.
3. Assert by checking exit code and output (e.g. `grep -q "expected" ./tmp/...`).
4. Support `--verbose` for extra logging when the runner passes it.

To run the optional forever concurrency integration test (mock CLI, one iteration):

```bash
RUN_FOREVER_INTEGRATION=1 ./__tests__/run-tests.sh
```
