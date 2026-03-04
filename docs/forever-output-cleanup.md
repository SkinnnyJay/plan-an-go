# Forever script output: before and after cleanup

This doc compares the **previous** `plan-an-go-forever.sh` output with the **implemented** cleanup. The same information is still shown: plan path and size, log, CLI, loops, started time, plan status, **Slack** (on/off/threads), **Validation** (on/off), **Stream** (on/off), tail path, and Ctrl+C hint. One-line iteration progress includes **Verdict** when validation is on. Use `--verbose` (or `PLAN_AN_GO_VERBOSE=true`) for full iteration summaries and plan-check output; use `--quiet` (or `PLAN_AN_GO_QUIET=true`) for minimal output (header + errors + final only). Samples: `__tests__/artifacts/forever-output-before.txt` (before), `__tests__/artifacts/forever-output-after.txt` (after).

---

## Before (current output)

```
✅ Validation passed: PLAN=/Volumes/BlackBox/GitHub/plan-an-go/./tmp/forever-concurrency.plan.md (319 bytes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 Plan-an-go Pipeline - Implementer Only Mode
   (7-step: Plan → Think → Research → Distill → Sub-tasks → Work → Validate; sub-agents when available)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Parent loops: 1
🔄 Child loops (per agent): 1
📝 Log file: ./tmp/history.log
📢 Slack: disabled
🔍 Validation: DISABLED
📺 Streaming: disabled
🤖 CLI: claude
📋 Plan file: /Volumes/BlackBox/GitHub/plan-an-go/./tmp/forever-concurrency.plan.md
📋 Plan status: COMPLETE
⏰ Started: 2026-03-04 00:51:41

Pipeline: IMPLEMENTER → LOG → SLACK (no validation)
⏸️  Press Ctrl+C to stop gracefully after current iteration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 ITERATION 1 of 1
⏰ 2026-03-04 00:51:41
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 STAGE 1: Running 2 Implementer Agents (concurrent)...
   M1:1- Task one [IN_PROGRESS]:[AGENT_01]
   M1:2- Task two [IN_PROGRESS]:[AGENT_02]


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ IMPLEMENTER FAILED - EXIT_CODE_127
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Output received (3498 chars):
**VALIDATION PASSED** ✅
...
```

**Issues:**

- **Long absolute paths** — Plan path is noisy (`/Volumes/..././tmp/...`); byte count adds little value on first line.
- **Redundant banner** — Same Unicode line repeated many times; heavy visually.
- **Duplicate info** — "Plan file" and "Plan status" repeated; "CLI: claude" and "Implementer Only" both say mode.
- **Internal markers in task lines** — `[IN_PROGRESS]:[AGENT_01]` is for the orchestrator; users care about "Task one" / "Task two".
- **Failure block** — "Output received (N chars)" plus raw dump is verbose; first few lines of output are enough, with a pointer to the log file.
- **Plan check** (when it runs) — Very verbose (counts, formatting, summary); useful for debug but noisy in the main loop.

---

## After (recommended)

### 1. Validation and header (startup)

**Before:**

```
✅ Validation passed: PLAN=/Volumes/BlackBox/GitHub/plan-an-go/./tmp/forever-concurrency.plan.md (319 bytes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 Plan-an-go Pipeline - Implementer Only Mode
   (7-step: Plan → Think → Research → Distill → Sub-tasks → Work → Validate; sub-agents when available)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Parent loops: 1
🔄 Child loops (per agent): 1
📝 Log file: ./tmp/history.log
...
```

**After:**

```
Plan-an-go · Implementer only (no validation)
  Plan: ./tmp/forever-concurrency.plan.md (319 B)  ·  Log: ./tmp/history.log  ·  CLI: claude
  Loops: 1 parent, 1 child  ·  Started 2026-03-04 00:51:41  ·  Plan: COMPLETE
  Slack: off  ·  Validation: off  ·  Stream: off
  Ctrl+C to stop after current iteration
```

**Changes:**

- One short title line; no thick Unicode banner.
- Plan path: relative when under CWD (e.g. `./tmp/...`), otherwise shorten (e.g. `.../plan-an-go/tmp/...`).
- Single line for plan + log + CLI; second line for loops + start time.
- Drop byte count and "Validation passed" (success is implied by proceeding).

### 2. Iteration start

**Before:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 ITERATION 1 of 1
⏰ 2026-03-04 00:51:41
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 STAGE 1: Running 2 Implementer Agents (concurrent)...
   M1:1- Task one [IN_PROGRESS]:[AGENT_01]
   M1:2- Task two [IN_PROGRESS]:[AGENT_02]
```

**After:**

```
--- Iteration 1/1 (2026-03-04 00:51:41) ---
Implementer (2 concurrent): M1:1 Task one · M1:2 Task two
```

**Changes:**

- Single separator line; iteration and time on one line.
- One line for implementer: label + task IDs and short descriptions only (no `[IN_PROGRESS]:[AGENT_NN]` in user-facing output).

### 3. Implementer failure

**Before:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ IMPLEMENTER FAILED - EXIT_CODE_127
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Output received (3498 chars):
**VALIDATION PASSED** ✅
...
------START: IMPLEMENTER------
...
```

**After:**

```
Implementer failed (exit 127). First 10 lines:
  **VALIDATION PASSED** ✅
  All acceptance criteria have been met:
  ...
Full output: ./tmp/history.log
```

**Changes:**

- One line for the error + exit code.
- Show only first few lines of output, then point to log file (no "Output received (N chars)" or full dump).

### 4. Iteration summary (success path)

**Before (typical):**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 ITERATION 1 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Mode: NO_VALIDATION
⏱️  Duration: 00:01:23
📈 Confidence: N/A
✅ Verdict: SKIPPED
📌 Status: CONTINUE
📋 Plan: 2 incomplete (impl: 2, check: 0, ui: 0, func: 0)
⏳ Total elapsed: 00:01:23
📊 Avg/iteration: 83s
⏳ ETA remaining: 00:00:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**After:**

```
Iteration 1 · 1m23s · Plan: 2 incomplete · ETA: 0s
```

**Changes:**

- One line: iteration, duration, plan status, ETA. Omit mode/verdict/status when they’re the default (e.g. no validation).

### 5. Plan status block (after each iteration)

**Before:** Full `plan-an-go-plan-check.sh` output (counts, completion, formatting, summary).

**After (recommended):**

- **Default:** One line, e.g. `Plan: 2 incomplete (2 tasks, 2 milestones)`.
- **Verbose:** Only when `PLAN_AN_GO_VERBOSE=1` or `--verbose`, run the full plan-check script.

### 6. Completion / stop / max iterations

Keep a single short block, e.g.:

```
--- All tasks complete ---
  Iterations: 5  ·  Time: 0h12m34s  ·  Finished 2026-03-04 01:04:15
```

or

```
--- Stopped (Ctrl+C) ---
  Iterations: 3/100  ·  Time: 0h05m00s
```

**Changes:**

- No thick Unicode borders; one heading line + one info line.

---

## Implementation checklist

| Area | Change |
|------|--------|
| **Paths** | Prefer relative paths when under `$REPO_ROOT`; e.g. `${PLAN_FILE#$REPO_ROOT/}` or `./tmp/...`. |
| **Banners** | Replace `━━━...━━━` with a short `--- ... ---` or a single line. |
| **Startup** | Collapse to 3–4 lines: title, plan+log+CLI, loops+time, Ctrl+C hint. |
| **Iteration** | One separator line; one line for "Implementer (N concurrent): task list" with task IDs and descriptions only (strip `[IN_PROGRESS]:[AGENT_NN]` for display). |
| **Failure** | One-line error; first 5–10 lines of output; "Full output: $LOG_FILE". |
| **Summary** | One line: iteration, duration, plan status, ETA (hide mode/verdict when not validating). |
| **Plan check** | Run full script only when `PLAN_AN_GO_VERBOSE=1` or `--verbose`; otherwise print one-line plan status. |
| **Emoji** | Optional: reduce or make configurable (e.g. `PLAN_AN_GO_NO_EMOJI=1`) for logs/CI. |

---

## Optional: quiet mode

Add `--quiet` (or `PLAN_AN_GO_QUIET=1`) to:

- Suppress iteration summaries (only show errors and final completion/stop).
- Suppress plan-check output (still run it for exit code if needed).
- Keep logging to `history.log` unchanged.

This gives a clean experience for "run and check the log later" while keeping the current behavior for default and `--verbose`.
