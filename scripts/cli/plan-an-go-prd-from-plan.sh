#!/bin/bash
# plan-an-go-prd-from-plan.sh — Validate, correct, or generate PRD from a PLAN (file or string)
#
# Uses PLAN_AN_GO_CLI (claude | codex | cursor-agent). Reads PLAN from a file or
# --plan-string; optionally reads existing PRD from --prd path to fix in place.
# Writes a standardized PRD to the given path (default ./PRD.md).
#
# Usage:
#   ./plan-an-go-prd-from-plan.sh [options] [plan_file]
#   ./plan-an-go-prd-from-plan.sh --plan PATH [options]
#   ./plan-an-go-prd-from-plan.sh --plan-string "PLAN content..." [options]
#
# Options:
#   --plan PATH                      PLAN file (or use positional path)
#   --plan-string "..."              PLAN content as string (no file)
#   --prd PATH | --out PATH          Output PRD path (default: ./PRD.md)
#   --cli claude|codex|cursor-agent  CLI (default: PLAN_AN_GO_CLI or claude)
#   --cli-flags "<flags>"            Extra flags for the CLI
#
# Examples:
#   ./plan-an-go-prd-from-plan.sh PLAN.md
#   ./plan-an-go-prd-from-plan.sh --plan ./PLAN.md --prd ./PRD.md
#   ./plan-an-go-prd-from-plan.sh --plan-string "# PLAN — Foo\n\n**M1:0**\n[ ] - M1:1- Task" --out ./PRD.md

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="${PLAN_AN_GO_PROMPTS_DIR:-$REPO_ROOT/assets/prompts}"
[ -n "${PLAN_AN_GO_PROMPTS_DIR:-}" ] && [ "${PLAN_AN_GO_PROMPTS_DIR#/}" = "$PLAN_AN_GO_PROMPTS_DIR" ] && PROMPTS_DIR="$REPO_ROOT/$PLAN_AN_GO_PROMPTS_DIR"
PRD_FROM_PLAN_PROMPT="$PROMPTS_DIR/prd-from-plan.md"

CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
PLAN_FILE=""
PLAN_STRING=""
PRD_OUT=""
PREV_ARG=""

for arg in "$@"; do
  case $arg in
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --plan=*)
      PLAN_FILE="${arg#*=}"
      ;;
    --plan-string=*)
      PLAN_STRING="${arg#*=}"
      ;;
    --prd=*|--out=*)
      PRD_OUT="${arg#*=}"
      ;;
    --cli)
      ;;
    --cli-flags)
      ;;
    --plan)
      ;;
    --plan-string)
      ;;
    --prd|--out)
      ;;
    *)
      if [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      elif [ "${PREV_ARG}" = "--plan" ]; then
        PLAN_FILE="$arg"
      elif [ "${PREV_ARG}" = "--plan-string" ]; then
        PLAN_STRING="$arg"
      elif [ "${PREV_ARG}" = "--prd" ] || [ "${PREV_ARG}" = "--out" ]; then
        PRD_OUT="$arg"
      elif [[ "$arg" != --* ]]; then
        if [ -z "$PLAN_FILE" ] && [ -z "$PLAN_STRING" ]; then
          PLAN_FILE="$arg"
        fi
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

# Resolve CLI flags
if [ -z "$CLI_FLAGS" ]; then
  case "$CLI_BIN" in
    claude) CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    codex)  CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    *)      ;;
  esac
fi

[ -z "$PRD_OUT" ] && PRD_OUT="./PRD.md"

# Require PLAN from file or string
if [ -z "$PLAN_STRING" ] && [ -z "$PLAN_FILE" ]; then
  echo "Usage: $0 [--plan PATH] [--plan-string \"...\"] [--prd PATH] [plan_file]" >&2
  echo "   or: $0 --plan PATH [--prd PATH]  (default --prd: ./PRD.md)" >&2
  exit 1
fi

if [ -n "$PLAN_FILE" ] && [ ! -f "$PLAN_FILE" ]; then
  echo "ERROR: Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

if [ "$CLI_BIN" != "claude" ] && [ "$CLI_BIN" != "codex" ] && [ "$CLI_BIN" != "cursor-agent" ]; then
  echo "ERROR: --cli must be 'claude', 'codex', or 'cursor-agent' (got: $CLI_BIN)" >&2
  exit 1
fi

if [ ! -f "$PRD_FROM_PLAN_PROMPT" ]; then
  echo "ERROR: Prompt not found: $PRD_FROM_PLAN_PROMPT" >&2
  exit 1
fi

if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "ERROR: '$CLI_BIN' CLI not found in PATH" >&2
  exit 1
fi

TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"
temp_prompt=$(mktemp "$TMP_DIR/prd-from-plan-prompt.XXXXXX")
temp_out=$(mktemp "$TMP_DIR/prd-from-plan-out.XXXXXX")
temp_err=$(mktemp "$TMP_DIR/prd-from-plan-err.XXXXXX")
trap 'rm -f "$temp_prompt" "$temp_out" "$temp_err"' EXIT

# Log concisely
plan_src="string"
[ -n "$PLAN_FILE" ] && plan_src="$PLAN_FILE"
echo "prd-from-plan: plan=$plan_src prd=$PRD_OUT cli=$CLI_BIN" >&2

# Build prompt: instructions + PLAN + optional existing PRD
cat "$PRD_FROM_PLAN_PROMPT" >> "$temp_prompt"
echo "" >> "$temp_prompt"

echo "BEGIN PLAN" >> "$temp_prompt"
echo "" >> "$temp_prompt"
if [ -n "$PLAN_STRING" ]; then
  echo "$PLAN_STRING" >> "$temp_prompt"
else
  cat "$PLAN_FILE" >> "$temp_prompt"
fi
echo "" >> "$temp_prompt"
echo "END PLAN" >> "$temp_prompt"
echo "" >> "$temp_prompt"

if [ -f "$PRD_OUT" ] && [ -s "$PRD_OUT" ]; then
  echo "BEGIN EXISTING PRD" >> "$temp_prompt"
  echo "" >> "$temp_prompt"
  cat "$PRD_OUT" >> "$temp_prompt"
  echo "" >> "$temp_prompt"
  echo "END EXISTING PRD" >> "$temp_prompt"
fi

# Invoke CLI (same pattern as plan-an-go-prd.sh)
CLAUDE_MODEL="${PLAN_AN_GO_CLAUDE_MODEL:-claude-sonnet-4-20250514}"
CODEX_MODEL="${PLAN_AN_GO_CODEX_MODEL:-}"
CLI_ARGS=()
if [ "$CLI_BIN" = "claude" ]; then
  CLI_ARGS=(--model "$CLAUDE_MODEL" --dangerously-skip-permissions)
elif [ "$CLI_BIN" = "codex" ] && [ -n "$CODEX_MODEL" ]; then
  CLI_ARGS=(--model "$CODEX_MODEL")
fi
if [ -n "$CLI_FLAGS" ]; then
  read -r -a EXTRA_CLI_ARGS <<< "$CLI_FLAGS"
  CLI_ARGS+=("${EXTRA_CLI_ARGS[@]}")
fi

echo "[prd-from-plan] Generating PRD from plan with $CLI_BIN..." >&2
exit_code=0
set +e
if [ "$CLI_BIN" = "codex" ]; then
  codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_out" 2> "$temp_err"
  exit_code=$?
else
  "$CLI_BIN" "${CLI_ARGS[@]}" -p "@$temp_prompt" > "$temp_out" 2> "$temp_err"
  exit_code=$?
fi
set -e

if [ -s "$temp_err" ]; then
  grep -v '^\[Paste:' "$temp_err" 2>/dev/null | grep -v '^\[Test:' 2>/dev/null | cat >&2 || cat "$temp_err" >&2
fi

if [ $exit_code -ne 0 ]; then
  echo "ERROR: CLI exited with code $exit_code" >&2
  exit $exit_code
fi

mkdir -p "$(dirname "$PRD_OUT")"
cat "$temp_out" > "$PRD_OUT"
echo "[prd-from-plan] Wrote PRD to $PRD_OUT" >&2

exit 0
