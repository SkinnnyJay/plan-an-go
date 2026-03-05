#!/usr/bin/env bash
# Unit test: extract-incomplete-tasks.sh writes only header + incomplete task lines.
# Reads from __tests__/artifacts/PLAN.md; writes only to ./tmp/. Asserts output content.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT="$REPO_ROOT/scripts/cli/scripts/extract-incomplete-tasks.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLAN="$ARTIFACTS/PLAN.md"
OUT="./tmp/extract-incomplete-tasks.unit.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

if [ -n "$VERBOSE" ]; then
  echo "Input: $PLAN"
  echo "Output: $OUT"
fi

if [ ! -x "$EXTRACT" ]; then
  [ -f "$EXTRACT" ] || { echo "Missing script: $EXTRACT"; exit 1; }
  chmod +x "$EXTRACT" 2>/dev/null || true
fi

"$EXTRACT" "$PLAN" "$OUT" ""
exitcode=$?
if [ $exitcode -ne 0 ]; then
  if [ -n "$VERBOSE" ]; then echo "Script exit: $exitcode"; fi
  exit 1
fi

# Assert: output contains milestone headers and incomplete lines only (no [x])
grep -q '\*\*M1:0' "$OUT" || { echo "Expected M1:0 in output"; exit 1; }
grep -q '\*\*M2:0' "$OUT" || { echo "Expected M2:0 in output"; exit 1; }
grep -q 'M1:1-' "$OUT" || { echo "Expected incomplete M1:1 in output"; exit 1; }
grep -q 'M1:3-' "$OUT" || { echo "Expected incomplete M1:3 in output"; exit 1; }
grep -q 'M2:2-' "$OUT" || { echo "Expected incomplete M2:2 in output"; exit 1; }
# Must not contain completed task lines (pattern: [x] - M<n>:)
grep -q '^[[:space:]]*\[x\][[:space:]]*-[[:space:]]*M[0-9]' "$OUT" && { echo "Output must not contain completed task lines [x] - M"; exit 1; }
# Must not contain M1:2 or M2:1 (completed in artifact)
grep 'M1:2-' "$OUT" 2>/dev/null && { echo "Completed M1:2 must not appear"; exit 1; }
grep 'M2:1-' "$OUT" 2>/dev/null && { echo "Completed M2:1 must not appear"; exit 1; }

if [ -n "$VERBOSE" ]; then echo "Content check passed."; fi
exit 0
