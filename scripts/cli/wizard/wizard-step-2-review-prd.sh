#!/bin/bash
# wizard-step-2-review-prd.sh — Review PRD: show path, optional CLI review for revision suggestions
# Usage: ./wizard-step-2-review-prd.sh [--prd-path PATH] [--cli claude|codex|cursor-agent|gemini|goose|opencode]
#   Outputs path to revision notes file (or empty). State: WIZARD_REVISIONS_FILE (optional).

set -e
set -o pipefail

WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$WIZARD_DIR/../.." && pwd)"
# shellcheck disable=SC2034
ROOT="${PLAN_AN_GO_ROOT:-$(pwd)}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"

PRD_PATH=""
CLI="${PLAN_AN_GO_CLI:-claude}"
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-path=*) PRD_PATH="${arg#*=}" ;;
    --cli=*) CLI="${arg#*=}" ;;
    --prd-path) ;;
    --cli) ;;
    *)
      if [ "$PREV_ARG" = "--prd-path" ]; then
        PRD_PATH="$arg"
      elif [ "$PREV_ARG" = "--cli" ]; then
        # shellcheck disable=SC2034
        CLI="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

if [ -f "$STATE_FILE" ]; then source "$STATE_FILE" 2>/dev/null || true; fi
[ -z "$PRD_PATH" ] && PRD_PATH="${WIZARD_PRD_PATH:-}"

if [ -z "$PRD_PATH" ] || [ ! -f "$PRD_PATH" ]; then
  echo "ERROR: PRD file required (set WIZARD_PRD_PATH or --prd-path)" >&2
  exit 1
fi

echo "[wizard] Step 2: Review PRD — $PRD_PATH" >&2
REVISIONS_FILE=$(mktemp "$TMP_DIR/wizard-revisions.XXXXXX")
echo "WIZARD_REVISIONS_FILE=$REVISIONS_FILE" >>"$STATE_FILE"

echo "Review the PRD and enter revision notes (one line or path to file); empty to skip:" >&2
read -r REV_INPUT
if [ -n "$REV_INPUT" ]; then
  if [ -f "$REV_INPUT" ]; then
    cat "$REV_INPUT" >"$REVISIONS_FILE"
  else
    echo "$REV_INPUT" >"$REVISIONS_FILE"
  fi
  echo "[wizard] Revisions saved." >&2
else
  echo "" >"$REVISIONS_FILE"
  echo "[wizard] No revisions." >&2
fi
