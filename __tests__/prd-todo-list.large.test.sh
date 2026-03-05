#!/usr/bin/env bash
# Large test: PRD-TODO-LIST.md artifact exists and optionally run planner to produce a PLAN.
# Uses __tests__/artifacts/PRD-TODO-LIST.md. Writes only to ./tmp/.
# Skip real planner (LLM) unless RUN_LARGE_TESTS=1 or PLAN_AN_GO_RUN_LARGE_TESTS=1.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLANNER="$REPO_ROOT/scripts/cli/plan-an-go-planner.sh"
PRD="$ARTIFACTS/PRD-TODO-LIST.md"
OUT_PLAN="./tmp/plan-todo-list.md"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# 1) Artifact must exist and look like a PRD
if [ ! -f "$PRD" ]; then
  echo "ERROR: Artifact not found: $PRD" >&2
  exit 1
fi
grep -q "^# PRD" "$PRD" || { echo "Expected # PRD in $PRD"; exit 1; }
grep -q "## Overview" "$PRD" || { echo "Expected ## Overview in $PRD"; exit 1; }
[ -n "$VERBOSE" ] && echo "  OK: PRD-TODO-LIST.md present and valid"

# 2) Optional: run planner (requires CLI/API; set RUN_LARGE_TESTS=1 or PLAN_AN_GO_RUN_LARGE_TESTS=1)
if [ -z "${RUN_LARGE_TESTS:-}" ] && [ -z "${PLAN_AN_GO_RUN_LARGE_TESTS:-}" ]; then
  [ -n "$VERBOSE" ] && echo "  Skipped planner (set RUN_LARGE_TESTS=1 to run)"
  exit 0
fi

"$PLANNER" --in "$PRD" --out "$OUT_PLAN" >> ./tmp/prd-todo-list.large.out 2>&1
exitcode=$?
if [ "$exitcode" -ne 0 ]; then
  echo "Planner failed (exit $exitcode); check CLI and API key" >&2
  cat ./tmp/prd-todo-list.large.out >&2
  exit 1
fi
[ ! -f "$OUT_PLAN" ] && { echo "Planner did not create $OUT_PLAN"; exit 1; }
grep -q "^# PLAN\|^## " "$OUT_PLAN" || { echo "Output plan missing PLAN header or milestones"; cat "$OUT_PLAN"; exit 1; }
[ -n "$VERBOSE" ] && echo "  OK: planner produced plan"
exit 0
