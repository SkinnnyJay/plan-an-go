# Repository Guidelines

## Project Structure & Module Organization
- `scripts/` holds the Bash pipeline tooling. Key areas: `scripts/cli/` for the implementer/validator/orchestrator commands, `scripts/system/` for setup/auth/verify helpers, and `scripts/runners/` for runner utilities. The main entry is `scripts/plan-an-go`.
- `agents/` contains agent configuration (`config.json`) plus prompt/MCP templates used by the CLI.
- `docs/ENV-README.md` documents environment variables; `.env.sample` is the starting point for local config.
- `examples/count/` provides a runnable example; `assets/` contains README imagery.
- Runtime artifacts: `PLAN.md` in workspace root; progress log, history log, and temp files under `./tmp/` by default (override with `PLAN_AN_GO_TMP`).

## Build, Test, and Development Commands
- `npm run plan-an-go`: run one implementer cycle against `PLAN.md`.
- `npm run plan-an-go-forever -- 100 50`: run implement → validate loops continuously.
- `npm run plan-an-go-validate -- <file>`: validate a saved implementer output.
- `npm run plan-an-go-planner -- --prompt "..." --out ./PLAN.md`: generate a plan file.
- `npm run plan-an-go-task-watcher -- --plan ./PLAN.md`: live task view (requires `fswatch`).
- `npm run setup`, `npm run install-clis`, `npm run auth-cli`, `npm run verify`: system setup and CLI checks.
- `npm run spellcheck`: run cspell on docs and scripts; `npm run spellcheck:fix` to add unknown words to dictionary.
- `npm run lint`: ShellCheck + spellcheck; `npm run lint:sh`: ShellCheck only; `npm run format` / `npm run format:write`: check or fix shell formatting (shfmt); `npm run check`: lint + format check.

## Coding Style & Naming Conventions
- Bash is the primary language; keep scripts portable for macOS/Linux and use `#!/bin/bash` with `set -e` in new scripts.
- Follow existing two-space indentation and descriptive variable names.
- Script names follow `plan-an-go-*.sh` in `scripts/cli/` and `scripts/system/`.
- Environment variables are uppercase and prefixed with `PLAN_AN_GO_` (see `docs/ENV-README.md`).

### Bash script best practices (scripts in `scripts/`)
- Use `set -e` and `set -o pipefail` so the script exits on first failure and pipeline failures are not ignored.
- Initialize loop/state variables before use (e.g. `PREV_ARG=""` before arg-parsing loops) so scripts are safe under `set -u` if adopted later.
- Prefer a `cleanup()` function and `trap cleanup EXIT` for temp files; only `rm -f` paths when the variable is set (e.g. `[ -n "${temp_file:-}" ] && rm -f "$temp_file"`) so early exits do not reference unset vars.
- Quote all expansions (e.g. `"$var"`, `"${arr[@]}"`). For lists of paths, prefer arrays and `"${arr[@]}"` over unquoted `$var` in `for` loops.
- Send user-facing errors to stderr: `echo "ERROR: ..." >&2` and `exit 1`.
- Use `mktemp` for temp files; avoid fixed names in `/tmp` to avoid collisions.
- Run `npm run lint` (or `make lint`) to run ShellCheck and spellcheck; run `npm run check` (or `make check`) before commits to include format checks. Use `npm run format:write` (or `make format-write`) to fix shell formatting. Requires shellcheck and shfmt (e.g. `brew install shellcheck shfmt`).

## Testing Guidelines
- Script tests live in `__tests__/`; run with `npm test` or `npm run test:verbose`. All test output is written only to `./tmp/`. Use `__tests__/artifacts/` for PLAN/PRD and config fixtures.
- Test file names: `filename.<type>.test.sh` (e.g. `extract-incomplete-tasks.unit.test.sh`). Pass `--verbose` to the runner to see each test’s output.
- Use `npm run verify` to ensure required CLIs and API keys are available.
- For a smoke check, run `npm run example:count` and confirm the example completes.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:` plus a short summary.
- Keep PRs focused, link relevant issues, and include command output or screenshots for user-visible CLI changes.
- Update `README.md`/`docs/ENV-README.md` when behavior or configuration changes, and add yourself to `CONTRIBUTORS.md` after your first merged PR.

## Security & Configuration Tips
- Copy `.env.sample` to `.env` and keep secrets (API keys, Slack tokens) out of version control.
- When running against another repo, set `PLAN_AN_GO_ROOT` and/or pass `--workspace` and `--plan` to scripts. To build into a specific directory (e.g. `./example/todo`) without overwriting repo root, use `--out-dir DIR` with run, forever, planner, or prd; optional `--clean-after --force` (forever only) removes workspace contents after exit. See `docs/ENV-README.md` (Output directory and cleanup).
