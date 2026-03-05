#!/usr/bin/env bash
# Output test: plan-an-go-planner.sh missing required input, invalid --cli, missing input file.
# Captures output to ./tmp/; no real CLI invocation. Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLANNER="$REPO_ROOT/scripts/cli/plan-an-go-planner.sh"
OUT="./tmp/plan-an-go-planner.output.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# 1) No --prompt and no input file: usage and exit 1
if "$PLANNER" --out ./tmp/planner-out.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit when no input"; exit 1
fi
grep -q "Usage:" "$OUT" || { echo "Expected Usage when no input"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: no input shows usage"; fi

# 2) --in nonexistent file: error and exit 1
> "$OUT"
if "$PLANNER" --in ./tmp/nonexistent-prd.md --out ./tmp/planner-out.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for missing input file"; exit 1
fi
grep -q "Input file not found" "$OUT" || { echo "Expected 'Input file not found'"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: missing input file"; fi

# 3) Invalid --cli (fails before calling CLI)
> "$OUT"
if "$PLANNER" --cli=invalid --prompt="x" --out ./tmp/planner-out.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for invalid --cli"; exit 1
fi
grep -q "ERROR: --cli must be" "$OUT" || { echo "Expected 'ERROR: --cli must be'"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: invalid --cli"; fi

exit 0
