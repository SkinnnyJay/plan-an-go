#!/bin/bash
# wizard-step-5-write-file.sh — Ensure PRD is written at chosen path (no-op if already there)
# Usage: ./wizard-step-5-write-file.sh [--prd-path PATH]
# Step 1 already wrote the file; this step is a checkpoint for "write file based on step 1 choice".

set -e
set -o pipefail

STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"

PRD_PATH=""
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-path=*) PRD_PATH="${arg#*=}" ;;
    --prd-path)  ;;
    *)
      if [ "$PREV_ARG" = "--prd-path" ]; then PRD_PATH="$arg"; fi
      ;;
  esac
  PREV_ARG="$arg"
done

[ -f "$STATE_FILE" ] && source "$STATE_FILE" 2>/dev/null || true
[ -z "$PRD_PATH" ] && PRD_PATH="${WIZARD_PRD_PATH:-}"

echo "[wizard] Step 5: Write file" >&2
if [ -z "$PRD_PATH" ]; then
  echo "ERROR: PRD path not set" >&2
  exit 1
fi
if [ ! -f "$PRD_PATH" ]; then
  echo "ERROR: PRD not found (run step 1 first): $PRD_PATH" >&2
  exit 1
fi
echo "[wizard] Step 5 done: $PRD_PATH" >&2
exit 0
