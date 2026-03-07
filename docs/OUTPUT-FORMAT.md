# Output format

This document describes the stdout layout for human-readable output and the JSON event schema when using `--output-type=json` with the plan-an-go orchestrator (`plan-an-go-forever`).

## Stdout (default: `--output-type=stdout`)

When output type is `stdout`, the orchestrator prints a human-readable stream:

- **Header:** Plan path, log path, CLI, agent count, milestones/task counts, loops, started time, status, Slack/validation/stream flags.
- **Per iteration:** Optional "In Progress" block (tasks being worked on), then implementer/validator progress. After each iteration: one-line summary (iteration, duration, plan status, verdict, ETA) or a verbose block.
- **Workers (multi-agent):** When running with `--concurrency N`, a "Workers" block can appear every few seconds with one line per running agent: `[IN_PROGRESS]:[AGENT_NN] · CPU X% · Y MB` and the task description.
- **Completion blocks:** After the pool phase, per-agent completion lines: `[COMPLETE]:[AGENT_NN] · CPU X% · Y MB` and the task line.
- **Final:** Either "All tasks complete", "Stopped (Ctrl+C)", or "Max iterations reached" with iterations, time, and log path.

Section separators use a simple `+----------+-----+---------------------------------------------------------+` style (no box-drawing characters). Agent colors (when enabled) are applied to agent names and status symbols; use `--highlight-agents` to color the full line for each agent. Use `--no-color` to disable colors.

## JSON (`--output-type=json`)

When output type is `json`, **only** JSON objects are written to stdout (one per line). No human-readable header, iteration lines, Workers, or completion blocks are printed to stdout. Progress and errors may still go to stderr.

Use `PLAN_AN_GO_OUTPUT_TYPE=json` or `--output-type=json` (or `--output-type json`).

### Event: `pipeline_start`

Emitted once at the start of the run.

| Field            | Type   | Description                                      |
|------------------|--------|--------------------------------------------------|
| `event`          | string | `"pipeline_start"`                               |
| `plan`           | string | Plan file path (display form)                    |
| `cli`            | string | CLI name (e.g. `codex`, `claude`)                |
| `concurrency`    | number | Number of concurrent implementer agents          |
| `max_iterations` | number | Maximum orchestrator iterations                  |
| `started_at`     | string | ISO-like timestamp when the pipeline started     |
| `validation`     | boolean| `true` if validator is enabled, `false` if `--no-validate` |

Example:

```json
{"event":"pipeline_start","plan":"./PLAN.md","cli":"codex","concurrency":2,"max_iterations":100,"started_at":"2026-03-05T12:00:00","validation":true}
```

### Event: `iteration_end`

Emitted after each iteration (implementer and, if enabled, validator).

| Field           | Type   | Description                          |
|-----------------|--------|--------------------------------------|
| `event`         | string | `"iteration_end"`                   |
| `iteration`     | number | 1-based iteration index             |
| `duration_sec`  | number | Duration of this iteration in seconds |
| `plan_status`   | string | Result of plan completion check (e.g. `"COMPLETE"`, `"2 incomplete"`) |
| `verdict`       | string | Validator verdict (e.g. `PASSED`, `FAILED`, `SKIPPED`) |
| `confidence`    | string | Confidence score from validator (e.g. `"10"`, `"N/A"`) |
| `eta_sec`       | number | Estimated seconds until end of run   |

Example:

```json
{"event":"iteration_end","iteration":3,"duration_sec":28,"plan_status":"1 incomplete","verdict":"PASSED","confidence":"10","eta_sec":28}
```

### Event: `pipeline_end`

Emitted once when the pipeline exits (all tasks complete, max iterations reached, or user stop).

| Field         | Type   | Description                                      |
|---------------|--------|--------------------------------------------------|
| `event`       | string | `"pipeline_end"`                                 |
| `reason`      | string | `"all_complete"`, `"max_iterations"`, or `"stopped"` |
| `iterations`  | number | Total iterations run                             |
| `total_sec`   | number | Total elapsed time in seconds                    |
| `plan_status` | string | Final plan completion status                     |

Example:

```json
{"event":"pipeline_end","reason":"all_complete","iterations":5,"total_sec":120,"plan_status":"COMPLETE"}
```

## Agent colors

- Colors can be set per agent in `agents/config.json` via the `color` field (`#rrggbb`). If unset or equal to the default (e.g. `#000`), a palette fallback is used.
- With `--no-color` (or non-TTY), no agent or status colors are applied.
- With `--highlight-agents`, the agent’s color is applied to the full task row (or full block in the orchestrator); otherwise only the agent name and status symbol (`o`, `✓`) use the agent color.

See [ENV-README.md](ENV-README.md) for `PLAN_AN_GO_USE_COLOR`, `PLAN_AN_GO_OUTPUT_TYPE`, and related options.
