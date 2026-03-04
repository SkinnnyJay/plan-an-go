#!/usr/bin/env bash
# Run the todo example: generate PLAN from PRD if needed, then run implementer loop.
# Run from repo root: ./examples/todo/run.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 1

EXAMPLES_DIR="examples/todo"
OUT_DIR="$ROOT/$EXAMPLES_DIR"
TMP_DIR="${PLAN_AN_GO_TMP:-$ROOT/tmp}"
mkdir -p "$TMP_DIR"
OUT_LOG="${TMP_DIR}/example-todo-run-$(date +%Y%m%d-%H%M%S).log"

if [ ! -f "$OUT_DIR/PLAN.md" ]; then
  echo "Generating PLAN.md from PRD..."
  PLANNER_OUT=$(mktemp "$TMP_DIR/todo-planner-out.XXXXXX")
  PLANNER_ERR=$(mktemp "$TMP_DIR/todo-planner-err.XXXXXX")
  if ! npm run plan-an-go-planner -- --out-dir "./$EXAMPLES_DIR" --in "./$EXAMPLES_DIR/PRD.md" > "$PLANNER_OUT" 2> "$PLANNER_ERR"; then
    echo "Planner failed. Check CLI and API key: npm run verify" >&2
    [ -s "$PLANNER_OUT" ] && { echo "--- stdout ---" >&2; cat "$PLANNER_OUT" >&2; }
    [ -s "$PLANNER_ERR" ] && { echo "--- stderr ---" >&2; cat "$PLANNER_ERR" >&2; }
    rm -f "$PLANNER_OUT" "$PLANNER_ERR"
    exit 1
  fi
  rm -f "$PLANNER_OUT" "$PLANNER_ERR"
fi

echo "Log: $OUT_LOG"
exec npm run plan-an-go-forever -- --out-dir "./$EXAMPLES_DIR" --plan PLAN.md --no-slack 2>&1 | tee "$OUT_LOG"
