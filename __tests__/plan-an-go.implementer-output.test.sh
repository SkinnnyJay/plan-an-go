#!/usr/bin/env bash
# Output test: plan-an-go.sh fail-early (no plan, empty plan, invalid --cli).
# Captures stdout/stderr to ./tmp/ and asserts ERROR/VERDICT: FAILED. No real CLI calls.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMPLEMENTER="$REPO_ROOT/scripts/cli/plan-an-go.sh"
# Unique dir per run so parallel runs or shared PLAN_AN_GO_TMP do not collide
TMPDIR=$(mktemp -d "$REPO_ROOT/tmp/implementer-output.XXXXXX")
STDOUT="$TMPDIR/stdout"
STDERR="$TMPDIR/stderr"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p "$TMPDIR"
# Use a clean empty workspace (no PLAN.md) for "plan not found" test; unique per run
EMPTY_WS=$(mktemp -d "$REPO_ROOT/tmp/empty-ws.XXXXXX")
cleanup_test_dirs() { rm -rf "$TMPDIR" "$EMPTY_WS"; }
trap cleanup_test_dirs EXIT

run_and_check() {
  local desc="$1"
  local want_in_output="$2"
  shift 2
  : > "$STDOUT"
  : > "$STDERR"
  "$IMPLEMENTER" "$@" >> "$STDOUT" 2>> "$STDERR" || true
  local combined
  combined="$(cat "$STDOUT" "$STDERR" 2>/dev/null)"
  if ! echo "$combined" | grep -q "$want_in_output"; then
    echo "Missing '$want_in_output' in output for: $desc"
    echo "Output: $combined"
    exit 1
  fi
  if [ -n "$VERBOSE" ]; then echo "  OK: $desc"; fi
}

# 1) Invalid --cli
run_and_check "invalid --cli" "ERROR: --cli must be 'claude'" --workspace "$REPO_ROOT" --cli=invalid
run_and_check "invalid --cli VERDICT" "VERDICT: FAILED" --workspace "$REPO_ROOT" --cli=invalid

# 2) No plan file (workspace with no PLAN.md)
run_and_check "plan file not found" "Plan file not found" --workspace "$EMPTY_WS"
run_and_check "plan not found VERDICT" "VERDICT: FAILED" --workspace "$EMPTY_WS"

# 3) Empty plan file (workspace with empty PLAN.md)
echo -n "" > "$EMPTY_WS/PLAN.md"
run_and_check "empty plan in workspace" "Plan file is empty" --workspace "$EMPTY_WS" --cli=claude
rm -f "$EMPTY_WS/PLAN.md"

if [ -n "$VERBOSE" ]; then echo "All implementer fail-early checks passed."; fi
exit 0
