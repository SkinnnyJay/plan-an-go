#!/bin/bash
# plan-an-go-wizard.sh — Guided PRD → review → update → validate → write → optional launch
# Usage: ./plan-an-go-wizard.sh [--skip N] [wizard args...]
#   Steps: 1 PRD wizard, 2 Review PRD, 3 Update PRD, 4 Validate, 5 Write file, 6 Launch (ask).
#   --skip N  Skip steps 1..N (use state file from previous run).
#   Other args passed to step 1 (e.g. --prd-out, --prompt, --cli). Does not change other workflows.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD_DIR="$SCRIPT_DIR/wizard"
ROOT="${PLAN_AN_GO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
STATE_FILE="$TMP_DIR/wizard-state"
SKIP=0
PREV_ARG=""
PASSTHROUGH=()

for arg in "$@"; do
  case "$arg" in
    --skip=*) SKIP="${arg#*=}" ;;
    --skip)   ;;
    *)
      if [ "$PREV_ARG" = "--skip" ]; then SKIP="$arg"
      else PASSTHROUGH+=("$arg")
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

mkdir -p "$TMP_DIR"
export WIZARD_STATE_FILE="$STATE_FILE"
export PLAN_AN_GO_ROOT="$ROOT"
# Clear state at start (fresh run)
if [ "$SKIP" -eq 0 ] && [ -f "$STATE_FILE" ]; then
  : > "$STATE_FILE"
fi

echo "plan-an-go wizard (PRD → review → update → validate → write → launch)" >&2

run_step() {
  local n="$1"
  local name="$2"
  shift 2
  echo "" >&2
  "$WIZARD_DIR/wizard-step-$n-$name.sh" "$@"
}

[ "$SKIP" -lt 1 ] && run_step 1 prd "${PASSTHROUGH[@]}" || true
[ "$SKIP" -lt 2 ] && run_step 2 review-prd || true
[ "$SKIP" -lt 3 ] && run_step 3 update-prd || true
[ "$SKIP" -lt 4 ] && run_step 4 validate-prd || true
[ "$SKIP" -lt 5 ] && run_step 5 write-file || true
[ "$SKIP" -lt 6 ] && run_step 6 launch || true

echo "" >&2
echo "[wizard] Done." >&2
