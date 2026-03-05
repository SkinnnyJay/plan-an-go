#!/usr/bin/env bash
# Output test: plan-an-go-forever.sh header format, --quiet, --verbose, and fail-early (invalid CLI, missing plan).
# Part A always runs (fail-early). Part B runs when RUN_FOREVER_INTEGRATION=1 (mock run, header/quiet/verbose).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FOREVER="$REPO_ROOT/scripts/cli/plan-an-go-forever.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
# Write to a fixed file under tmp/ so output is inspectable; tests must not depend on clean state
OUT="$REPO_ROOT/tmp/forever-output.test.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p "$REPO_ROOT/tmp"

run_and_check() {
  local desc="$1"
  local want="$2"
  shift 2
  : > "$OUT"
  "$FOREVER" "$@" >> "$OUT" 2>&1 || true
  if ! grep -q "$want" "$OUT"; then
    echo "Missing '$want' in output for: $desc" >&2
    cat "$OUT" >&2
    exit 1
  fi
  [ -n "$VERBOSE" ] && echo "  OK: $desc"
}

run_and_check_not() {
  local desc="$1"
  local notwant="$2"
  shift 2
  : > "$OUT"
  "$FOREVER" "$@" >> "$OUT" 2>&1 || true
  if grep -q "$notwant" "$OUT"; then
    echo "Should not contain '$notwant' in output for: $desc" >&2
    cat "$OUT" >&2
    exit 1
  fi
  [ -n "$VERBOSE" ] && echo "  OK: $desc (absent: $notwant)"
}

# ---------------------------------------------------------------------------
# Part A: Fail-early (no mock, no network)
# ---------------------------------------------------------------------------
# 1) Invalid CLI
: > "$OUT"
"$FOREVER" 1 1 --no-validate --plan "$ARTIFACTS/PLAN.md" --workspace "$REPO_ROOT" --cli=invalid >> "$OUT" 2>&1 || true
grep -q "got: invalid" "$OUT" || { echo "Missing 'got: invalid' in output (invalid --cli)" >&2; cat "$OUT" >&2; exit 1; }
[ -n "$VERBOSE" ] && echo "  OK: invalid --cli"

# 2) Missing plan
MISSING_PLAN="$REPO_ROOT/tmp/forever-output-nonexistent.plan.md"
: > "$OUT"
"$FOREVER" 1 1 --no-validate --plan "$MISSING_PLAN" --workspace "$REPO_ROOT" >> "$OUT" 2>&1 || true
grep -q "Plan file not found" "$OUT" || { echo "Missing 'Plan file not found' in output (missing plan)" >&2; cat "$OUT" >&2; exit 1; }
[ -n "$VERBOSE" ] && echo "  OK: missing plan file"

# ---------------------------------------------------------------------------
# Part B: Header format, --quiet, --verbose (requires mock; set RUN_FOREVER_INTEGRATION=1)
# ---------------------------------------------------------------------------
if [ -z "${RUN_FOREVER_INTEGRATION:-}" ]; then
  [ -n "$VERBOSE" ] && echo "  Skipped integration part (set RUN_FOREVER_INTEGRATION=1 to run)"
  exit 0
fi

# Setup: plan copy and mock claude (same as concurrency integration test)
PLAN_COPY="./tmp/forever-output.plan.md"
MOCK_CLI="./tmp/mock-claude"
mkdir -p ./tmp
[ ! -f "./tmp/progress.log" ] && echo "# Progress" > "./tmp/progress.log"
cp "$ARTIFACTS/PLAN-concurrency.md" "$PLAN_COPY"
cat > "$MOCK_CLI" << 'MOCK'
#!/usr/bin/env bash
cat > /dev/null
echo "------START: IMPLEMENTER------"
echo "Mock implementer"
echo "------END: IMPLEMENTER------"
exit 0
MOCK
chmod +x "$MOCK_CLI"
ln -sf mock-claude "$REPO_ROOT/tmp/claude"
export PATH="$REPO_ROOT/tmp:$PATH"

# Default run: assert compact header and one-line progress
: > "$OUT"
"$FOREVER" 1 1 --no-validate --concurrency 2 --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude >> "$OUT" 2>&1 || true
grep -q "Plan-an-go" "$OUT" || { echo "Header should contain Plan-an-go"; cat "$OUT"; exit 1; }
grep -q "Plan:.*B)" "$OUT" || { echo "Header should show plan path and size (N B)"; cat "$OUT"; exit 1; }
grep -q "Slack: off" "$OUT" || { echo "Header should show Slack: off"; cat "$OUT"; exit 1; }
grep -q "Validation: off" "$OUT" || { echo "Header should show Validation: off"; cat "$OUT"; exit 1; }
grep -q "Stream: off" "$OUT" || { echo "Header should show Stream: off"; cat "$OUT"; exit 1; }
grep -q -e "Iteration 1/1" "$OUT" || { echo "Output should contain iteration header"; cat "$OUT"; exit 1; }
grep -q "Implementer (2 concurrent)" "$OUT" || { echo "Output should mention Implementer (2 concurrent)"; cat "$OUT"; exit 1; }
grep -q "Iteration 1 ·" "$OUT" || { echo "Output should contain one-line summary 'Iteration 1 ·'"; cat "$OUT"; exit 1; }
[ -n "$VERBOSE" ] && echo "  OK: default run (header + iteration + one-line summary)"

# --quiet: no per-iteration lines, but header and final message
: > "$OUT"
"$FOREVER" 1 1 --no-validate --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude --quiet >> "$OUT" 2>&1 || true
grep -q "Plan-an-go" "$OUT" || { echo "Quiet run should show header"; cat "$OUT"; exit 1; }
grep -q "Max iterations reached\|All tasks complete" "$OUT" || { echo "Quiet run should show final message"; cat "$OUT"; exit 1; }
# Quiet run: no per-iteration header (pattern matches "--- Iteration 1/1 (date) ---" but not final "Iterations: 1/1")
run_and_check_not "quiet run should not show iteration header" "Iteration 1/1 (" 1 1 --no-validate --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude --quiet
run_and_check_not "quiet run should not show Implementer: task" "Implementer: M1:1" 1 1 --no-validate --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude --quiet

# --verbose: full iteration summary or plan-check style output
: > "$OUT"
"$FOREVER" 1 1 --no-validate --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude --verbose >> "$OUT" 2>&1 || true
# Verbose shows either "Iteration 1 summary" block (Mode/Duration) or plan-check output (Milestones/Tasks/Complete)
{ grep -q "Mode:\|Duration:\|Iteration 1 summary" "$OUT" || grep -q "Milestones:\|Tasks:\|Complete:" "$OUT"; } || {
  echo "Verbose run should show summary block or plan-check output"
  cat "$OUT"
  exit 1
}
[ -n "$VERBOSE" ] && echo "  OK: verbose run (summary or plan-check)"

if [ -n "$VERBOSE" ]; then
  echo "All forever output tests passed."
fi
exit 0
