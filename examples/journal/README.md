# Journal example

Plan-an-go example: build a personal journal web app from this PRD (entries, tags, search, markdown, shadcn/ui).

- **PRD:** [PRD.md](./PRD.md)
- **Plan:** Generated into [PLAN.md](./PLAN.md) by the planner (see below).
- **Run from repo root:** `./examples/journal/run.sh` or run the commands below.

## Workflow

1. **Generate plan from PRD** (if PLAN.md does not exist):
   ```bash
   npm run plan-an-go-planner -- --out-dir ./examples/journal --in ./examples/journal/PRD.md
   ```

2. **Run implementer loop** (implement → validate until done or max iterations):
   ```bash
   npm run plan-an-go-forever -- --out-dir ./examples/journal --plan PLAN.md --no-slack
   ```

Or use the bundled script (generates PLAN from PRD when missing, then runs forever):

```bash
./examples/journal/run.sh
```

Requires a configured CLI (`claude`, `codex`, or `cursor-agent`). See repo root [README](../../README.md) for setup.
