#!/usr/bin/env bash
# run-tests.sh — Run all filename.<type>.test.sh in __tests__; output only to ./tmp/ and stdout.
# Usage: ./run-tests.sh [--verbose] [--smoke | --full] [--large] [--test NAME]
#   --verbose       Show each test name and full output; otherwise only pass/fail summary.
#   --smoke         Run smoke tests only (exclude *.large.test.sh). Default.
#   --full          Run full suite including *.large.test.sh (multi-app PRD/planner tests).
#   --large         Same as --full (backward compatible).
#   --test NAME     Run only tests whose path contains NAME (e.g. --test journal).
# Large tests (*.large.test.sh) are never run unless --full or --large is explicitly passed.
# Test types: smoke = unit + output + integration (no large); full = smoke + large.
# Tests must write only to ./tmp/. Artifacts live in __tests__/artifacts/.
# Exit: 0 if all pass, 1 if any fail.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

VERBOSE=""
INCLUDE_LARGE=""
TEST_FILTER=""
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    --smoke)   INCLUDE_LARGE="" ;;
    --full)    INCLUDE_LARGE=1 ;;
    --large)   INCLUDE_LARGE=1 ;;
    --test)
      TEST_FILTER="--test"
      ;;
    *)
      if [ "$TEST_FILTER" = "--test" ]; then
        TEST_FILTER="$arg"
      fi
      ;;
  esac
done

mkdir -p ./tmp
TESTS_DIR="$SCRIPT_DIR"
PASS=0
FAIL=0
FAILED_NAMES=()

run_one() {
  local t="$1"
  local name="${t##*/}"
  local out_file="./tmp/${name%.sh}.out"
  local err_file="./tmp/${name%.sh}.err"
  local args=()
  [ -n "$VERBOSE" ] && args+=(--verbose)

  if [ -n "$VERBOSE" ]; then
    echo "--- $name ---"
    if "$t" "${args[@]}" > "$out_file" 2> "$err_file"; then
      echo "PASS: $name"
      [ -s "$out_file" ] && cat "$out_file"
      [ -s "$err_file" ] && cat "$err_file" >&2
      return 0
    else
      echo "FAIL: $name (exit $?)"
      [ -s "$out_file" ] && cat "$out_file"
      [ -s "$err_file" ] && cat "$err_file" >&2
      return 1
    fi
  else
    if "$t" "${args[@]}" > "$out_file" 2> "$err_file"; then
      echo "  PASS  $name"
      return 0
    else
      echo "  FAIL  $name"
      return 1
    fi
  fi
}

if [ -n "$INCLUDE_LARGE" ]; then
  echo "Running full test suite (smoke + large; output under ./tmp/)"
else
  echo "Running smoke tests only (output under ./tmp/; use --full for full suite)"
fi
[ -n "$TEST_FILTER" ] && [ "$TEST_FILTER" != "--test" ] && echo "Filter: only tests matching: $TEST_FILTER"
echo ""

for t in "$TESTS_DIR"/*.*.test.sh; do
  [ -f "$t" ] || continue
  # Never run large tests unless user explicitly passed --full or --large
  if [[ "$t" == *".large.test.sh" ]]; then
    if [ -z "$INCLUDE_LARGE" ]; then
      continue
    fi
  fi
  # Single-test filter (e.g. --test journal)
  if [ -n "$TEST_FILTER" ] && [ "$TEST_FILTER" != "--test" ]; then
    case "$t" in
      *"$TEST_FILTER"*) ;;
      *) continue ;;
    esac
  fi
  if run_one "$t"; then
    ((PASS++)) || true
  else
    ((FAIL++)) || true
    FAILED_NAMES+=("${t##*/}")
  fi
done

echo ""
echo "----------------------------------------"
echo "  total: $((PASS + FAIL))  passed: $PASS  failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "  failed: ${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
