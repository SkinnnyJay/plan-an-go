#!/bin/bash
# plan-an-go-prd.sh — Generate a PRD.md from a freeform prompt or an input document
#
# Uses the same CLI as plan-an-go.sh (claude | codex | cursor-agent). Reads the
# PRD prompt from assets/prompts/prd.md and optionally the template from
# assets/prompts/prd-template.md. Output conforms to the agreed PRD format;
# default output file is ./PRD.md.
#
# Usage:
#   ./plan-an-go-prd.sh [options] [input file]
#   ./plan-an-go-prd.sh [options] --in PATH [options]
#   ./plan-an-go-prd.sh [options] --prompt="Describe the product or feature"
#
# Options:
#   --in PATH                         Input file (doc or draft to expand into PRD)
#   --out PATH                        Output file (default: ./PRD.md)
#   --cli claude|codex|cursor-agent   CLI to use (default: from PLAN_AN_GO_CLI or claude)
#   --cli-flags "<flags>"             Extra flags for the CLI
#   --prompt="..."                    Use this string as the input instead of a file
#
# Examples:
#   ./plan-an-go-prd.sh --prompt="Build a small CLI that prints Hello and exits"
#   ./plan-an-go-prd.sh --in notes.md --out ./PRD.md
#   ./plan-an-go-prd.sh --cli cursor-agent --prompt="New API endpoint for users list"

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="${PLAN_AN_GO_PROMPTS_DIR:-$REPO_ROOT/assets/prompts}"
[ -n "${PLAN_AN_GO_PROMPTS_DIR:-}" ] && [ "${PLAN_AN_GO_PROMPTS_DIR#/}" = "$PLAN_AN_GO_PROMPTS_DIR" ] && PROMPTS_DIR="$REPO_ROOT/$PLAN_AN_GO_PROMPTS_DIR"
PRD_PROMPT="$PROMPTS_DIR/prd.md"
TEMPLATE_FILE="$PROMPTS_DIR/prd-template.md"

CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
OUT_FILE=""
INPUT_FILE=""
USER_PROMPT=""
PREV_ARG=""

for arg in "$@"; do
  case $arg in
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --in=*)
      INPUT_FILE="${arg#*=}"
      ;;
    --out=*)
      OUT_FILE="${arg#*=}"
      ;;
    --prompt=*)
      USER_PROMPT="${arg#*=}"
      ;;
    --cli)
      ;;
    --cli-flags)
      ;;
    --in)
      ;;
    --out)
      ;;
    *)
      if [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      elif [ "${PREV_ARG}" = "--in" ]; then
        INPUT_FILE="$arg"
      elif [ "${PREV_ARG}" = "--out" ]; then
        OUT_FILE="$arg"
      elif [[ "$arg" != --* ]]; then
        if [ -z "$USER_PROMPT" ] && [ -z "$INPUT_FILE" ]; then
          INPUT_FILE="$arg"
        fi
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

# Resolve CLI flags: use PLAN_AN_GO_CLI_FLAGS if set, else per-CLI vars
if [ -z "$CLI_FLAGS" ]; then
  case "$CLI_BIN" in
    claude) CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    codex)  CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    *)      ;;
  esac
fi

# Default output path (relative to cwd when script was invoked)
[ -z "$OUT_FILE" ] && OUT_FILE="./PRD.md"

# Require either an input file or --prompt
if [ -z "$USER_PROMPT" ] && [ -z "$INPUT_FILE" ]; then
  echo "Usage: $0 [--in PATH] [--out PATH] [--cli ...] (input file)" >&2
  echo "   or: $0 [options] --in PATH   (explicit input file)" >&2
  echo "   or: $0 [options] --prompt=\"Your product or feature description\"" >&2
  echo "Default output: ./PRD.md" >&2
  exit 1
fi

if [ -n "$INPUT_FILE" ] && [ ! -f "$INPUT_FILE" ]; then
  echo "ERROR: Input file not found: $INPUT_FILE" >&2
  exit 1
fi

if [ "$CLI_BIN" != "claude" ] && [ "$CLI_BIN" != "codex" ] && [ "$CLI_BIN" != "cursor-agent" ]; then
  echo "ERROR: --cli must be 'claude', 'codex', or 'cursor-agent' (got: $CLI_BIN)" >&2
  exit 1
fi

if [ ! -f "$PRD_PROMPT" ]; then
  echo "ERROR: PRD prompt not found: $PRD_PROMPT" >&2
  exit 1
fi

if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "ERROR: '$CLI_BIN' CLI not found in PATH" >&2
  exit 1
fi

TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"

# Build full prompt: instructions + template first, then INPUT last
temp_prompt=$(mktemp "$TMP_DIR/prd-prompt.XXXXXX")
temp_out=$(mktemp "$TMP_DIR/prd-out.XXXXXX")
temp_err=$(mktemp "$TMP_DIR/prd-err.XXXXXX")
trap 'rm -f "$temp_prompt" "$temp_out" "$temp_err"' EXIT

cat "$PRD_PROMPT" >> "$temp_prompt"
echo "" >> "$temp_prompt"

if [ -f "$TEMPLATE_FILE" ]; then
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
  echo "REFERENCE TEMPLATE (match this structure)" >> "$temp_prompt"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
  cat "$TEMPLATE_FILE" >> "$temp_prompt"
  echo "" >> "$temp_prompt"
fi

echo "BEGIN INPUT DOCUMENT" >> "$temp_prompt"
echo "" >> "$temp_prompt"
if [ -n "$USER_PROMPT" ]; then
  echo "$USER_PROMPT" >> "$temp_prompt"
else
  cat "$INPUT_FILE" >> "$temp_prompt"
fi
echo "" >> "$temp_prompt"
echo "END INPUT DOCUMENT" >> "$temp_prompt"

# Invoke CLI (same pattern as plan-an-go-planner.sh)
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

echo "[prd] Generating PRD with $CLI_BIN..." >&2
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

# Write output to target file
mkdir -p "$(dirname "$OUT_FILE")"
cat "$temp_out" > "$OUT_FILE"
echo "[prd] Wrote PRD to $OUT_FILE" >&2

exit 0
