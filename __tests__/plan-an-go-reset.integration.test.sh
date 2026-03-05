#!/usr/bin/env bash
# Integration test: plan-an-go-reset.sh resets [x] to [ ] and reports count.
# Copies artifact PLAN to ./tmp/, runs reset, asserts stdout and file content. Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESET="$REPO_ROOT/scripts/cli/plan-an-go-reset.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLAN_SRC="$ARTIFACTS/PLAN.md"
WORK_PLAN="./tmp/reset-test-plan.md"
STDOUT="./tmp/plan-an-go-reset.integration.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp
cp "$PLAN_SRC" "$WORK_PLAN"

if [ -n "$VERBOSE" ]; then
  echo "Plan copy: $WORK_PLAN"
  echo "Running: $RESET --plan $WORK_PLAN --force"
fi

"$RESET" --plan "$WORK_PLAN" --force > "$STDOUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  if [ -n "$VERBOSE" ]; then cat "$STDOUT"; fi
  exit 1
fi

# Assert: message says we reset some tasks (artifact has 3 completed)
grep -q "Reset.*task(s)" "$STDOUT" || { echo "Expected 'Reset N task(s)' in output"; exit 1; }
# Assert: plan no longer has [x] on task lines (all became [ ])
! grep -q '^[[:space:]]*\[x\][[:space:]]*-[[:space:]]*M' "$WORK_PLAN" || { echo "Plan should have no [x] task lines after reset"; exit 1; }

if [ -n "$VERBOSE" ]; then echo "Reset count and file content OK."; fi
exit 0
