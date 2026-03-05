#!/usr/bin/env bash
# Unit test: Concurrency marking — first N incomplete tasks get [IN_PROGRESS]:[AGENT_01] .. [AGENT_N].
# Replicates the logic from plan-an-go-forever.sh (strip_in_progress_from_file + mark_next_n_incomplete_in_progress)
# so we assert the contract without running the full pipeline. Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS="$SCRIPT_DIR/artifacts"
PLAN_SRC="$ARTIFACTS/PLAN-concurrency.md"
PLAN_COPY="./tmp/concurrency-marking.plan.md"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp
cp "$PLAN_SRC" "$PLAN_COPY"

# Replicate strip_in_progress_from_file (so we start clean)
sed -e 's/ \[IN_PROGRESS\]:\[AGENT_[0-9]*\]//g' -e 's/ \[IN_PROGRESS\]//g' "$PLAN_COPY" > "${PLAN_COPY}.tmp" && mv "${PLAN_COPY}.tmp" "$PLAN_COPY"

# Replicate mark_next_n_incomplete_in_progress for n=2
n=2
line_nums=$(grep -n -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$PLAN_COPY" 2>/dev/null | head -n "$n" | cut -d: -f1) || true
idx=1
sed_expr=""
for ln in $line_nums; do
  agent_id=$(printf 'AGENT_%02d' "$idx")
  sed_expr="${sed_expr}${sed_expr:+;}${ln}s/\$/ [IN_PROGRESS]:[${agent_id}]/"
  idx=$(( idx + 1 ))
done
[ -n "$sed_expr" ] && sed "$sed_expr" "$PLAN_COPY" > "${PLAN_COPY}.tmp" && mv "${PLAN_COPY}.tmp" "$PLAN_COPY"

# Assert: exactly two lines have [IN_PROGRESS]:[AGENT_01] and [IN_PROGRESS]:[AGENT_02]
grep -q '\[IN_PROGRESS\]:\[AGENT_01\]' "$PLAN_COPY" || { echo "Plan must contain [IN_PROGRESS]:[AGENT_01]"; exit 1; }
grep -q '\[IN_PROGRESS\]:\[AGENT_02\]' "$PLAN_COPY" || { echo "Plan must contain [IN_PROGRESS]:[AGENT_02]"; exit 1; }
count_01=$(grep -c '\[IN_PROGRESS\]:\[AGENT_01\]' "$PLAN_COPY" 2>/dev/null) || count_01=0
count_02=$(grep -c '\[IN_PROGRESS\]:\[AGENT_02\]' "$PLAN_COPY" 2>/dev/null) || count_02=0
[ "$count_01" -eq 1 ] || { echo "Expected exactly one AGENT_01 marker, got $count_01"; exit 1; }
[ "$count_02" -eq 1 ] || { echo "Expected exactly one AGENT_02 marker, got $count_02"; exit 1; }

# Third incomplete task must not be marked
if grep 'M1:3-' "$PLAN_COPY" | grep -q '\[IN_PROGRESS\]'; then
  echo "M1:3 must not have [IN_PROGRESS] when n=2"; exit 1
fi

if [ -n "$VERBOSE" ]; then
  echo "  strip + mark_next_n(2) OK"
  echo "  AGENT_01 and AGENT_02 markers present, M1:3 unmarked"
fi
exit 0
