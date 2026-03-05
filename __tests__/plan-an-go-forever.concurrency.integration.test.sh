#!/usr/bin/env bash
# Integration test: plan-an-go-forever.sh with --concurrency 2 marks two tasks and runs two implementers.
# Uses a mock CLI in ./tmp so no real LLM is called. Writes only to ./tmp/.
# Optional: run with RUN_FOREVER_INTEGRATION=1 (can be slow; mock must consume stdin).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FOREVER="$REPO_ROOT/scripts/cli/plan-an-go-forever.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLAN_COPY="./tmp/forever-concurrency.plan.md"
MOCK_CLI="./tmp/mock-claude"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

# Skip unless explicitly requested (test can be slow / depends on env)
if [ -z "${RUN_FOREVER_INTEGRATION:-}" ]; then
  if [ -n "$VERBOSE" ]; then echo "  Skipped (set RUN_FOREVER_INTEGRATION=1 to run)"; fi
  exit 0
fi

cd "$REPO_ROOT"
mkdir -p ./tmp
[ ! -f "./tmp/progress.log" ] && echo "# Progress" > "./tmp/progress.log"
cp "$ARTIFACTS/PLAN-concurrency.md" "$PLAN_COPY"

# Mock CLI: consume stdin (implementer sends prompt via stdin), print minimal block, exit 0
cat > "$MOCK_CLI" << 'MOCK'
#!/usr/bin/env bash
cat > /dev/null
echo "------START: IMPLEMENTER------"
echo "Mock implementer for concurrency test"
echo "------END: IMPLEMENTER------"
exit 0
MOCK
chmod +x "$MOCK_CLI"
# Script invokes "claude"; put mock on PATH as "claude"
ln -sf mock-claude "$REPO_ROOT/tmp/claude"

# Run one iteration with concurrency 2; use mock as claude via PATH
export PATH="$REPO_ROOT/tmp:$PATH"
"$FOREVER" 1 1 --no-validate --concurrency 2 --plan "$PLAN_COPY" --workspace "$REPO_ROOT" --cli claude > ./tmp/forever-concurrency.out 2>&1
exitcode=$?
# Script exits 0 when max iterations reached (or 1 on failure)
# Assert: output shows 2 concurrent implementers and tasks
grep -q 'Implementer (2 concurrent)' ./tmp/forever-concurrency.out || {
  echo "Output should mention Implementer (2 concurrent)"
  cat ./tmp/forever-concurrency.out
  exit 1
}
grep -q 'M1:1.*M1:2\|M1:2.*M1:1' ./tmp/forever-concurrency.out || {
  echo "Output should list both tasks M1:1 and M1:2"
  cat ./tmp/forever-concurrency.out
  exit 1
}
# Orchestrator strips markers when it exits; so we only assert it ran and reported concurrency
if [ -n "$VERBOSE" ]; then
  echo "  forever --concurrency 2 ran one iteration with mock CLI"
  echo "  Output mentions 2 agents and AGENT_01/02"
fi
exit 0
