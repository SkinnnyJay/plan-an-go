#!/bin/bash
# plan-an-go-planner.sh — Generate a PLAN.md from a PRD file or a freeform prompt
#
# Uses the same CLI as plan-an-go.sh (claude | codex | cursor-agent). Reads the
# planning prompt from assets/prompts/planning.md and optionally the template from
# assets/prompts/template.md. Output conforms to the agreed PLAN format; default
# output file is ./PLAN.md.
#
# Usage:
#   ./plan-an-go-planner.sh [options] [PRD.md or other input file]
#   ./plan-an-go-planner.sh [options] --in PATH [options]
#   ./plan-an-go-planner.sh [options] --prompt="I need a blue button, click does x, auth driven"
#
# Options:
#   --in PATH                         Input file (PRD or other doc to plan from)
#   --out PATH                        Output file (default: ./PLAN.md)
#   --cli claude|codex|cursor-agent   CLI to use (default: from PLAN_AN_GO_CLI or claude)
#   --cli-flags "<flags>"             Extra flags for the CLI
#   --prompt="..."                    Use this string as the planning input instead of a file
#
# Examples:
#   ./plan-an-go-planner.sh PRD.md
#   ./plan-an-go-planner.sh --in PLAN.md --out ./my-plan.md
#   ./plan-an-go-planner.sh --prompt="Add a blue feature button; on click go to x; auth only"
#   ./plan-an-go-planner.sh --cli cursor-agent --prompt="New API endpoint for users list"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPTS_DIR="$REPO_ROOT/assets/prompts"
PLANNING_PROMPT="$PROMPTS_DIR/planning.md"
TEMPLATE_FILE="$PROMPTS_DIR/template.md"

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
        # Positional: treat as input file (only if not using --prompt or --in)
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
[ -z "$OUT_FILE" ] && OUT_FILE="./PLAN.md"

# Temp files under ./tmp
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"

# Require either an input file or --prompt
if [ -z "$USER_PROMPT" ] && [ -z "$INPUT_FILE" ]; then
  echo "Usage: $0 [--in PATH] [--out PATH] [--cli ...] (PRD.md | other file)" >&2
  echo "   or: $0 [options] --in PATH   (explicit input file)" >&2
  echo "   or: $0 [options] --prompt=\"Your planning request here\"" >&2
  echo "Default output: ./PLAN.md" >&2
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

if [ ! -f "$PLANNING_PROMPT" ]; then
  echo "ERROR: Planning prompt not found: $PLANNING_PROMPT" >&2
  exit 1
fi

if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "ERROR: '$CLI_BIN' CLI not found in PATH" >&2
  exit 1
fi

# Build full prompt: instructions + template first, then INPUT DOCUMENT last so the model sees it
temp_prompt=$(mktemp "$TMP_DIR/planner-prompt.XXXXXX")
temp_out=$(mktemp "$TMP_DIR/planner-out.XXXXXX")
temp_err=$(mktemp "$TMP_DIR/planner-err.XXXXXX")
trap 'rm -f "$temp_prompt" "$temp_out" "$temp_err"' EXIT

cat "$PLANNING_PROMPT" >> "$temp_prompt"
echo "" >> "$temp_prompt"

# Template reference (before input so "match this structure" is clear)
if [ -f "$TEMPLATE_FILE" ]; then
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
  echo "REFERENCE TEMPLATE (match this structure)" >> "$temp_prompt"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
  cat "$TEMPLATE_FILE" >> "$temp_prompt"
  echo "" >> "$temp_prompt"
fi

# Input document at the very end so the model definitely sees it
echo "BEGIN INPUT DOCUMENT" >> "$temp_prompt"
echo "" >> "$temp_prompt"
if [ -n "$USER_PROMPT" ]; then
  echo "$USER_PROMPT" >> "$temp_prompt"
else
  cat "$INPUT_FILE" >> "$temp_prompt"
fi
echo "" >> "$temp_prompt"
echo "END INPUT DOCUMENT" >> "$temp_prompt"

# Invoke CLI (same pattern as plan-an-go.sh)
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

if [ "$CLI_BIN" = "codex" ]; then
  codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_out" 2> "$temp_err"
  exit_code=$?
else
  "$CLI_BIN" "${CLI_ARGS[@]}" -p "@$temp_prompt" > "$temp_out" 2> "$temp_err"
  exit_code=$?
fi

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
echo "Wrote PLAN to $OUT_FILE"

# Optional: run plan check if available
plan_check="$SCRIPT_DIR/plan-an-go-plan-check.sh"
if [ -f "$plan_check" ] && [ -x "$plan_check" ]; then
  "$plan_check" "$OUT_FILE" || true
fi

exit 0
