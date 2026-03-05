# Test artifacts

Sample PLAN.md, PRD.md (and optional config) for script tests. Tests must not modify these files; copy to `./tmp/` when a test needs to mutate a plan.

## PRD fixtures (scope / shadcn)

| File | Scope | Description |
|------|--------|-------------|
| `PRD.md` | — | Minimal generic PRD |
| `PRD-VACATION-AIRBNB.md` | Medium | Vacation TODO + Airbnb integration |
| `PRD-TODO-LIST.md` | Small | Todo list CRUD, filters, sort; **shadcn required** |
| `PRD-JOURNAL.md` | Medium | Journal with entries, tags, search, markdown; **shadcn required** |
| `PRD-YOUTUBE-CLONE.md` | Large | YouTube clone with real videos (Data API + embed), playlists, watch later; **shadcn required** |

All frontend PRD examples above require **shadcn/ui** as the UI component framework.

## Large tests (PRD artifacts)

Each of the four PRD fixtures above has a corresponding **large test** in `__tests__/`:

| Artifact | Test script | npm command |
|----------|-------------|-------------|
| `PRD-JOURNAL.md` | `prd-journal.large.test.sh` | `npm run test:journal` |
| `PRD-TODO-LIST.md` | `prd-todo-list.large.test.sh` | `npm run test:todo-list` |
| `PRD-VACATION-AIRBNB.md` | `prd-vacation-airbnb.large.test.sh` | `npm run test:vacation-airbnb` |
| `PRD-YOUTUBE-CLONE.md` | `prd-youtube-clone.large.test.sh` | `npm run test:youtube-clone` |

- Large tests are **excluded** from the default `npm test` (so CI stays fast). Run all large tests with `npm run test:large`, or a single one with `npm run test:<name>`.
- Each large test (1) asserts the PRD artifact exists and has valid structure, (2) optionally runs the planner (LLM) when `RUN_LARGE_TESTS=1` or `PLAN_AN_GO_RUN_LARGE_TESTS=1` to produce a PLAN and assert output format.

## Forever script output

| File | Description |
|------|--------------|
| `forever-output-before.log` | Captured real stdout/stderr from `plan-an-go-forever.sh` before cleanup (for comparison). |
| `forever-output-after.log` | Example of cleaned-up output format after implementation (see `docs/forever-output-cleanup.md`). |
