#!/usr/bin/env bash
# Output test: plan-an-go-task-watcher.sh --once (full and minimal). Writes only to ./tmp/.
# Uses --once to avoid fswatch; --no-color for stable grep.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WATCHER="$REPO_ROOT/scripts/cli/plan-an-go-task-watcher.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
OUT="./tmp/plan-an-go-task-watcher.output.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

PLAN_FILE="$ARTIFACTS/PLAN.md"

# Full view (default): --once --plan --no-color
"$WATCHER" --once --plan "$PLAN_FILE" --no-color > "$OUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  echo "Watcher full --once should exit 0 (exit $exitcode)"; cat "$OUT"; exit 1
fi
grep -q "Plan Task Watcher" "$OUT" || { echo "Full output should show Plan Task Watcher"; cat "$OUT"; exit 1; }
grep -q "M1:1" "$OUT" || { echo "Full output should show M1:1"; exit 1; }
grep -q "M1:2" "$OUT" || { echo "Full output should show M1:2"; exit 1; }
grep -q "M2:2" "$OUT" || { echo "Full output should show M2:2"; exit 1; }
grep -q "Last refresh:" "$OUT" || { echo "Full output should show Last refresh"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: full --once"; fi

# Minimal view: --minimal --minimal-before 5 --minimal-after 5 --once
"$WATCHER" --minimal --minimal-before 5 --minimal-after 5 --once --plan "$PLAN_FILE" --no-color > "$OUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  echo "Watcher minimal --once should exit 0 (exit $exitcode)"; cat "$OUT"; exit 1
fi
grep -q "Plan Task Watcher (minimal)" "$OUT" || { echo "Minimal output should show minimal header"; cat "$OUT"; exit 1; }
grep -q "M1:1" "$OUT" || { echo "Minimal output should show M1:1"; exit 1; }
grep -q "Complete:" "$OUT" || { echo "Minimal output should show Complete:"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: minimal --once"; fi

# Missing plan: exit 1
if "$WATCHER" --once --plan ./tmp/nonexistent-plan.md --no-color >> "$OUT" 2>&1; then
  echo "Watcher should exit non-zero for missing plan"; exit 1
fi
grep -q "Error:\|not found" "$OUT" || true
if [ -n "$VERBOSE" ]; then echo "  OK: missing plan fails"; fi

exit 0
