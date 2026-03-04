#!/bin/bash
# wizard-step-6-launch.sh — Ask to launch plan-an-go forever with --plan; optionally generate PLAN from PRD first
# Usage: ./wizard-step-6-launch.sh [--prd-path PATH] [--plan-path PATH] [--no-ask]

set -e

WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$WIZARD_DIR/../.." && pwd)"
ROOT="${PLAN_AN_GO_ROOT:-$(pwd)}"
STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"

PRD_PATH=""
PLAN_PATH=""
NO_ASK=""
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-path=*) PRD_PATH="${arg#*=}" ;;
    --plan-path=*) PLAN_PATH="${arg#*=}" ;;
    --no-ask)     NO_ASK=1 ;;
    --prd-path)   ;;
    --plan-path)  ;;
    *)
      if [ "$PREV_ARG" = "--prd-path" ]; then PRD_PATH="$arg"
      elif [ "$PREV_ARG" = "--plan-path" ]; then PLAN_PATH="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

[ -f "$STATE_FILE" ] && source "$STATE_FILE" 2>/dev/null || true
[ -z "$PRD_PATH" ] && PRD_PATH="${WIZARD_PRD_PATH:-}"
[ -z "$PLAN_PATH" ] && PLAN_PATH="${WIZARD_PLAN_PATH:-$ROOT/PLAN.md}"

# Resolve plan path relative to root
if [ "${PLAN_PATH#/}" = "$PLAN_PATH" ]; then
  PLAN_PATH="$ROOT/$PLAN_PATH"
fi

echo "[wizard] Step 6: Launch" >&2
if [ -z "$NO_ASK" ]; then
  echo "Launch plan-an-go forever with --plan $PLAN_PATH? (y/N)" >&2
  read -r LAUNCH
  case "$LAUNCH" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "[wizard] Skip launch." >&2; exit 0 ;;
  esac
fi

if [ ! -f "$PLAN_PATH" ] && [ -n "$PRD_PATH" ] && [ -f "$PRD_PATH" ]; then
  echo "[wizard] Generating PLAN from PRD..." >&2
  (cd "$ROOT" && "$SCRIPT_DIR/plan-an-go" planner --in "$PRD_PATH" --out "$PLAN_PATH" ${WIZARD_CLI:+--cli "$WIZARD_CLI"})
fi

if [ ! -f "$PLAN_PATH" ]; then
  echo "ERROR: Plan file not found: $PLAN_PATH (generate with: plan-an-go planner --in PRD.md --out $PLAN_PATH)" >&2
  exit 1
fi

echo "[wizard] Running: plan-an-go forever --plan $PLAN_PATH" >&2
(cd "$ROOT" && exec "$SCRIPT_DIR/plan-an-go" forever --plan "$PLAN_PATH" "$@")
