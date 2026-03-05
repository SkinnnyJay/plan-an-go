#!/usr/bin/env bash
# Unit test: extract-incomplete-tasks.sh with PLAN_AN_GO_AGENT_ID filters to only that agent's task.
# Uses __tests__/artifacts/PLAN-concurrency.md; writes only to ./tmp/. Asserts output contains
# only the line(s) with [IN_PROGRESS]:[AGENT_xx] for the given agent.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXTRACT="$REPO_ROOT/scripts/cli/scripts/extract-incomplete-tasks.sh"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLAN_SRC="$ARTIFACTS/PLAN-concurrency.md"
PLAN_COPY="./tmp/extract-agent-id.plan.md"
OUT_01="./tmp/extract-agent-id.AGENT_01.out"
OUT_02="./tmp/extract-agent-id.AGENT_02.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp
cp "$PLAN_SRC" "$PLAN_COPY"

# Mark first two incomplete tasks with [IN_PROGRESS]:[AGENT_01] and [IN_PROGRESS]:[AGENT_02]
# (same pattern as plan-an-go-forever.sh mark_next_n_incomplete_in_progress)
line_nums=$(grep -n -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$PLAN_COPY" 2>/dev/null | head -n 2 | cut -d: -f1) || true
idx=1
for ln in $line_nums; do
  agent_id=$(printf 'AGENT_%02d' "$idx")
  sed "${ln}s/\$/ [IN_PROGRESS]:[${agent_id}]/" "$PLAN_COPY" > "${PLAN_COPY}.tmp" && mv "${PLAN_COPY}.tmp" "$PLAN_COPY"
  idx=$(( idx + 1 ))
done

# AGENT_01: output must contain M1:1 (its task) and must not contain M1:2 or M1:3
"$EXTRACT" "$PLAN_COPY" "$OUT_01" "AGENT_01"
if ! grep -q 'M1:1-' "$OUT_01"; then
  echo "AGENT_01 output must contain M1:1"; exit 1
fi
if grep -q 'M1:2-' "$OUT_01" 2>/dev/null; then
  echo "AGENT_01 output must not contain M1:2 (other agent's task)"; exit 1
fi
if grep -q 'M1:3-' "$OUT_01" 2>/dev/null; then
  echo "AGENT_01 output must not contain M1:3 (unassigned task)"; exit 1
fi

# AGENT_02: output must contain M1:2 and must not contain M1:1 or M1:3
"$EXTRACT" "$PLAN_COPY" "$OUT_02" "AGENT_02"
if ! grep -q 'M1:2-' "$OUT_02"; then
  echo "AGENT_02 output must contain M1:2"; exit 1
fi
if grep -q 'M1:1-' "$OUT_02" 2>/dev/null; then
  echo "AGENT_02 output must not contain M1:1"; exit 1
fi
if grep -q 'M1:3-' "$OUT_02" 2>/dev/null; then
  echo "AGENT_02 output must not contain M1:3"; exit 1
fi

if [ -n "$VERBOSE" ]; then
  echo "  AGENT_01 filter OK"
  echo "  AGENT_02 filter OK"
fi
exit 0
