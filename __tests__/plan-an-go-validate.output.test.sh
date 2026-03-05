#!/usr/bin/env bash
# Output test: plan-an-go-validate.sh fail-early (missing implementer output, missing plan).
# Captures output to ./tmp/ and asserts ERROR/VERDICT: FAILED. No real CLI calls.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/cli/plan-an-go-validate.sh"
# Unique dir per run so parallel runs or shared PLAN_AN_GO_TMP do not collide
TMPDIR=$(mktemp -d "$REPO_ROOT/tmp/validate-output.XXXXXX")
STDOUT="$TMPDIR/stdout"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

run_and_check() {
  local desc="$1"
  local want="$2"
  shift 2
  : > "$STDOUT"
  "$VALIDATOR" "$@" >> "$STDOUT" 2>&1 || true
  if ! grep -q "$want" "$STDOUT"; then
    echo "Missing '$want' in output for: $desc"
    cat "$STDOUT"
    exit 1
  fi
  if [ -n "$VERBOSE" ]; then echo "  OK: $desc"; fi
}

# 1) Missing implementer output (no args)
run_and_check "missing implementer output" "Implementer output file required" ""
run_and_check "missing implementer VERDICT" "VERDICT: FAILED" ""

# 2) Non-existent implementer output file
run_and_check "nonexistent output file" "Implementer output file required" "$TMPDIR/nonexistent-implementer.out"

# 3) Invalid --cli (use dummy existing file and workspace with PLAN.md so we reach CLI check)
# Use repo-root tmp so validator does not create __tests__/artifacts/tmp/progress.log
touch "$TMPDIR/dummy-implementer.out"
export PLAN_AN_GO_TMP="$REPO_ROOT/tmp"
run_and_check "invalid --cli" "ERROR: --cli must be" "$TMPDIR/dummy-implementer.out" --workspace "$REPO_ROOT/__tests__/artifacts" --cli=invalid
unset -v PLAN_AN_GO_TMP

if [ -n "$VERBOSE" ]; then echo "All validator fail-early checks passed."; fi
exit 0
