#!/bin/bash
# plan-an-go-reset.sh — Reset completed tasks from [x] to [ ] in a plan file.
# Usage: plan-an-go-reset.sh [--plan FILE] [--milestone N | -m N] [--force]
#   --plan FILE   Plan file (default: ./PLAN.md)
#   --milestone N, -m N   Only reset tasks in milestone N (e.g. 1 for M1:1, M1:2, ...)
#   --force       Do not create a .bak backup before modifying.
# By default, creates <plan>.bak before changing the file.
# Exit: 0 on success, 1 if plan missing or invalid args.

set -e
set -o pipefail

PLAN_FILE=""
MILESTONE=""
FORCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_FILE="${2:?Missing value for --plan}"
      shift 2
      ;;
    --plan=*)
      PLAN_FILE="${1#*=}"
      shift
      ;;
    -m|--milestone)
      MILESTONE="${2:?Missing value for --milestone}"
      shift 2
      ;;
    --milestone=*)
      MILESTONE="${1#*=}"
      shift
      ;;
    -f|--force)
      FORCE=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--plan FILE] [--milestone N | -m N] [--force]"
      echo "  Reset completed tasks [x] to [ ] in a plan file."
      echo "  --plan FILE    Plan file (default: ./PLAN.md)"
      echo "  --milestone N  Only reset tasks in milestone N (e.g. 1 for M1:1, M1:2, ...)"
      echo "  --force        Do not create a .bak backup before modifying."
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$PLAN_FILE" ]]; then
        PLAN_FILE="$1"
      fi
      shift
      ;;
  esac
done

PLAN_FILE="${PLAN_FILE:-./PLAN.md}"

TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

if [[ -n "$MILESTONE" && ! "$MILESTONE" =~ ^[0-9]+$ ]]; then
  echo "Milestone must be a positive number." >&2
  exit 1
fi

# Only replace [x] on task lines: optional leading space, [x], then " - M<num>:"
# This avoids changing prose like "All tasks are marked [x]".
reset_count=0
TMP_FILE=$(mktemp "$TMP_DIR/reset.XXXXXX")
trap 'rm -f "$TMP_FILE"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^[[:space:]]*\[x\][[:space:]]*-[[:space:]]*M([0-9]+): ]]; then
    current_m="${BASH_REMATCH[1]}"
    if [[ -z "$MILESTONE" || "$MILESTONE" == "$current_m" ]]; then
      new_line="${line//\[x\]/[ ]}"
      echo "$new_line"
      ((reset_count++)) || true
    else
      echo "$line"
    fi
  else
    echo "$line"
  fi
done < "$PLAN_FILE" > "$TMP_FILE"

if [[ -z "$FORCE" ]]; then
  cp "$PLAN_FILE" "${PLAN_FILE}.bak"
fi
mv "$TMP_FILE" "$PLAN_FILE"

if [[ $reset_count -gt 0 ]]; then
  echo "Reset $reset_count task(s) to incomplete in $PLAN_FILE"
else
  echo "No completed tasks to reset in $PLAN_FILE"
fi
