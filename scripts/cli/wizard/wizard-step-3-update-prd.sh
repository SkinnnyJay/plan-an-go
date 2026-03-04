#!/bin/bash
# wizard-step-3-update-prd.sh — Update PRD from revision notes (run plan-an-go prd --in PRD --prompt revisions)
# Usage: ./wizard-step-3-update-prd.sh [--prd-path PATH] [--revisions-file PATH]

set -e
set -o pipefail

WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$WIZARD_DIR/../.." && pwd)"
ROOT="${PLAN_AN_GO_ROOT:-$(pwd)}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"

PRD_PATH=""
REVISIONS_FILE=""
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-path=*)       PRD_PATH="${arg#*=}" ;;
    --revisions-file=*) REVISIONS_FILE="${arg#*=}" ;;
    --prd-path)        ;;
    --revisions-file)  ;;
    *)
      if [ "$PREV_ARG" = "--prd-path" ]; then PRD_PATH="$arg"
      elif [ "$PREV_ARG" = "--revisions-file" ]; then REVISIONS_FILE="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

[ -f "$STATE_FILE" ] && source "$STATE_FILE" 2>/dev/null || true
[ -z "$PRD_PATH" ] && PRD_PATH="${WIZARD_PRD_PATH:-}"
[ -z "$REVISIONS_FILE" ] && REVISIONS_FILE="${WIZARD_REVISIONS_FILE:-}"

if [ -z "$PRD_PATH" ] || [ ! -f "$PRD_PATH" ]; then
  echo "ERROR: PRD file required" >&2
  exit 1
fi

echo "[wizard] Step 3: Update PRD" >&2
if [ -z "$REVISIONS_FILE" ] || [ ! -s "$REVISIONS_FILE" ]; then
  echo "[wizard] No revisions; skip update." >&2
  exit 0
fi

REV_PROMPT="Apply these revision notes to the PRD. Output only the updated PRD.

Revision notes:
$(cat "$REVISIONS_FILE")"
(cd "$ROOT" && "$SCRIPT_DIR/plan-an-go" prd --in "$PRD_PATH" --out "$PRD_PATH" --prompt="$REV_PROMPT" ${WIZARD_CLI:+--cli "$WIZARD_CLI"})
echo "[wizard] Step 3 done." >&2
