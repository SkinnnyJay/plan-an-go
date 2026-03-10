#!/bin/bash
# wizard-step-4-validate-prd.sh — Validate PRD file (exists, non-empty, has structure)
# Usage: ./wizard-step-4-validate-prd.sh [--prd-path PATH]
# Exit: 0 valid, 1 invalid.

set -e
set -o pipefail

# shellcheck disable=SC2034
WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"

PRD_PATH=""
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-path=*) PRD_PATH="${arg#*=}" ;;
    --prd-path) ;;
    *)
      if [ "$PREV_ARG" = "--prd-path" ]; then PRD_PATH="$arg"; fi
      ;;
  esac
  PREV_ARG="$arg"
done

if [ -f "$STATE_FILE" ]; then source "$STATE_FILE" 2>/dev/null || true; fi
[ -z "$PRD_PATH" ] && PRD_PATH="${WIZARD_PRD_PATH:-}"

echo "[wizard] Step 4: Validate PRD" >&2
if [ -z "$PRD_PATH" ]; then
  echo "ERROR: PRD path not set" >&2
  exit 1
fi
if [ ! -f "$PRD_PATH" ]; then
  echo "ERROR: PRD not found: $PRD_PATH" >&2
  exit 1
fi
if [ ! -s "$PRD_PATH" ]; then
  echo "ERROR: PRD is empty" >&2
  exit 1
fi
if ! grep -qE '^#|^##' "$PRD_PATH" 2>/dev/null; then
  echo "WARN: PRD has no markdown headings" >&2
fi
echo "[wizard] Step 4 OK: $PRD_PATH" >&2
exit 0
