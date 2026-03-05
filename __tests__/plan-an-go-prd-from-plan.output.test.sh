#!/usr/bin/env bash
# Output test: plan-an-go-prd-from-plan.sh missing required plan, invalid --cli, missing plan file.
# No real CLI invocation. Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PRD_FROM_PLAN="$REPO_ROOT/scripts/cli/plan-an-go-prd-from-plan.sh"
OUT="./tmp/plan-an-go-prd-from-plan.output.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# 1) No --plan, no --plan-string, no positional: usage and exit 1
if "$PRD_FROM_PLAN" --prd ./tmp/out-prd.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit when no plan"; exit 1
fi
grep -q "Usage:" "$OUT" || { echo "Expected Usage when no plan"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: no plan shows usage"; fi

# 2) --plan nonexistent file: error and exit 1
> "$OUT"
if "$PRD_FROM_PLAN" --plan ./tmp/nonexistent-plan.md --prd ./tmp/out-prd.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for missing plan file"; exit 1
fi
grep -q "Plan file not found\|not found" "$OUT" || { echo "Expected plan file error"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: missing plan file"; fi

# 3) Invalid --cli (fails before calling CLI)
> "$OUT"
if "$PRD_FROM_PLAN" --cli=invalid --plan ./__tests__/artifacts/PLAN.md --prd ./tmp/out-prd.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for invalid --cli"; exit 1
fi
grep -q "ERROR: --cli must be" "$OUT" || { echo "Expected ERROR: --cli must be"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: invalid --cli"; fi

# 4) --plan-string with no file: script accepts it (would fail later at CLI if no CLI)
#    We only check that with --plan-string we don't get "Usage" (script has a plan source)
> "$OUT"
# Prompt file must exist; CLI may not be available. So we only test that invalid --cli still fails
# when combined with --plan-string (same as test 3 but with string input)
if "$PRD_FROM_PLAN" --plan-string="# PLAN — Foo" --cli=invalid --prd ./tmp/out-prd.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for invalid --cli with --plan-string"; exit 1
fi
grep -q "ERROR: --cli must be" "$OUT" || { echo "Expected ERROR: --cli with --plan-string"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: --plan-string + invalid --cli"; fi

exit 0
