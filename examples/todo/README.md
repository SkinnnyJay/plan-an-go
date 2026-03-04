# Todo List example

Plan-an-go example: build a minimal todo list web app from this PRD (TypeScript, React, Next.js, Prisma, SQLite, shadcn/ui).

- **PRD:** [PRD.md](./PRD.md)
- **Plan:** Generated into [PLAN.md](./PLAN.md) by the planner (see below).
- **Run from repo root:** `./examples/todo/run.sh` or run the commands below.

## Workflow

1. **Generate plan from PRD** (if PLAN.md does not exist):
   ```bash
   npm run plan-an-go-planner -- --out-dir ./examples/todo --in ./examples/todo/PRD.md
   ```

2. **Run implementer loop** (implement → validate until done or max iterations):
   ```bash
   npm run plan-an-go-forever -- --out-dir ./examples/todo --plan PLAN.md --no-slack
   ```

Or use the bundled script (generates PLAN from PRD when missing, then runs forever):

```bash
./examples/todo/run.sh
```

Requires a configured CLI (`claude`, `codex`, or `cursor-agent`). See repo root [README](../../README.md) for setup.

## If PLAN.md has no tasks (failed planner run)

If PLAN.md was created but contains only a run log (e.g. Codex errors) and no `**M1:0**` milestones or `[ ] - M1:1-` task lines, the planner run failed and the CLI’s stdout was saved as PLAN.md. Fix:

1. Remove the bad plan: `rm examples/todo/PLAN.md`
2. Use a working CLI (e.g. Claude): `PLAN_AN_GO_CLI=claude npm run plan-an-go-planner -- --out-dir ./examples/todo --in ./examples/todo/PRD.md`
3. Confirm PLAN.md starts with `# PLAN —` and has milestones/tasks, then run `./examples/todo/run.sh` again.
