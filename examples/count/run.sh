#!/usr/bin/env bash
# Run the count example: pipeline for examples/count/PLAN.md.
# Prints the log file path at the top, then streams output (also written to that file).
# Run from repo root: ./examples/count/run.sh   or   npm run example:count

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 1

OUT="${SCRIPT_DIR}/run-$(date +%Y%m%d-%H%M%S).log"
echo "$OUT"
exec ./scripts/cli/plan-an-go-forever.sh 5 25 \
  --workspace "$ROOT/examples/count" \
  --plan PLAN.md \
  --no-slack \
  2>&1 | tee "$OUT"
