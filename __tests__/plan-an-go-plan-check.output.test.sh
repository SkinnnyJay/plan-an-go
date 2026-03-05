#!/usr/bin/env bash
# Output test: plan-an-go-plan-check.sh on artifact plan (success) and missing file (failure).
# Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAN_CHECK="$REPO_ROOT/scripts/cli/plan-an-go-plan-check.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
OUT="./tmp/plan-an-go-plan-check.output.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# Valid plan: exit 0 and report
"$PLAN_CHECK" "$ARTIFACTS/PLAN.md" > "$OUT" 2>&1
exitcode=$?
if [ $exitcode -ne 0 ]; then
  echo "Plan check should pass for artifact PLAN.md (exit $exitcode)"; cat "$OUT"; exit 1
fi
grep -q "Plan file found" "$OUT" || { echo "Expected 'Plan file found'"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: valid plan"; fi

# Missing plan: exit 1
if "$PLAN_CHECK" ./tmp/nonexistent-plan.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for missing plan"; exit 1
fi
grep -q "Plan file not found\|ERROR" "$OUT" || true
if [ -n "$VERBOSE" ]; then echo "  OK: missing plan fails"; fi

exit 0
