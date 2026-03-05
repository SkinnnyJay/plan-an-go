#!/usr/bin/env bash
# Output test: plan-an-go entry (help, unknown subcommand). Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENTRY="$REPO_ROOT/scripts/plan-an-go"
OUT="./tmp/plan-an-go.entry.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# Help
"$ENTRY" help > "$OUT" 2>&1
grep -q "plan-an-go" "$OUT" || { echo "Help should mention plan-an-go"; exit 1; }
grep -q "Subcommands:" "$OUT" || { echo "Help should list subcommands"; exit 1; }
grep -q "wizard" "$OUT" || { echo "Help should list wizard subcommand"; exit 1; }
grep -q "prd" "$OUT" || { echo "Help should list prd subcommand"; exit 1; }
grep -q "prd-from-plan" "$OUT" || { echo "Help should list prd-from-plan subcommand"; exit 1; }
grep -q "task-watcher" "$OUT" || { echo "Help should list task-watcher subcommand"; exit 1; }
grep -q "task-watcher-minimal" "$OUT" || { echo "Help should list task-watcher-minimal subcommand"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: help"; fi

# Unknown subcommand
if "$ENTRY" unknown-subcommand-xyz > "$OUT" 2>&1; then
  echo "Expected non-zero exit for unknown subcommand"; exit 1
fi
grep -q "Unknown subcommand" "$OUT" || { echo "Should report unknown subcommand"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: unknown subcommand"; fi

# prd-from-plan with no plan: usage from script, exit 1
if "$ENTRY" prd-from-plan > "$OUT" 2>&1; then
  echo "Expected non-zero exit for prd-from-plan with no plan"; exit 1
fi
grep -q "Usage:" "$OUT" || { echo "prd-from-plan no plan should show Usage"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: prd-from-plan no plan"; fi

# task-watcher with --once and --plan: single run, exit 0, full view
PLAN_FILE="$SCRIPT_DIR/artifacts/PLAN.md"
"$ENTRY" task-watcher --once --plan "$PLAN_FILE" --no-color > "$OUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  echo "task-watcher --once should exit 0 (exit $exitcode)"; cat "$OUT"; exit 1
fi
grep -q "Plan Task Watcher" "$OUT" || { echo "task-watcher output should show Plan Task Watcher"; cat "$OUT"; exit 1; }
grep -q "M1:1" "$OUT" || { echo "task-watcher output should show task ID M1:1"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: task-watcher --once"; fi

# task-watcher-minimal with --once and --plan: single run, exit 0, minimal view (5 before/5 after)
"$ENTRY" task-watcher-minimal --once --plan "$PLAN_FILE" --no-color > "$OUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  echo "task-watcher-minimal --once should exit 0 (exit $exitcode)"; cat "$OUT"; exit 1
fi
grep -q "Plan Task Watcher (minimal)" "$OUT" || { echo "task-watcher-minimal output should show minimal header"; cat "$OUT"; exit 1; }
grep -q "M1:1" "$OUT" || { echo "task-watcher-minimal output should show task ID M1:1"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: task-watcher-minimal --once"; fi

exit 0
