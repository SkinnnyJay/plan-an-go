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
#   --task-detail L|M|H|XH            Task granularity: L=low, M=medium (default), H=high, XH=extra high
#   --cli claude|codex|cursor-agent   CLI to use (default: from PLAN_AN_GO_CLI or claude)
#   --cli-flags "<flags>"             Extra flags for the CLI
#   --prompt="..."                    Use this string as the planning input instead of a file
#
# Examples:
#   ./plan-an-go-planner.sh PRD.md
#   ./plan-an-go-planner.sh --in PLAN.md --out ./my-plan.md
#   ./plan-an-go-planner.sh --task-detail XH --in PRD.md   (extra-high granularity)
#   ./plan-an-go-planner.sh --prompt="Add a blue feature button; on click go to x; auth only"
#   ./plan-an-go-planner.sh --cli cursor-agent --prompt="New API endpoint for users list"

set -e
set -o pipefail

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
TASK_DETAIL="${PLAN_AN_GO_TASK_DETAIL:-M}"
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
    --task-detail=*)
      TASK_DETAIL="${arg#*=}"
      ;;
    --cli)
      ;;
    --cli-flags)
      ;;
    --in)
      ;;
    --out)
      ;;
    --task-detail)
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
      elif [ "${PREV_ARG}" = "--task-detail" ]; then
        TASK_DETAIL="$arg"
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

# Normalize task detail to uppercase for comparison
TASK_DETAIL="$(echo "$TASK_DETAIL" | tr '[:lower:]' '[:upper:]')"
case "$TASK_DETAIL" in
  L|LOW)           TASK_DETAIL="L" ;;
  M|MEDIUM)        TASK_DETAIL="M" ;;
  H|HIGH)          TASK_DETAIL="H" ;;
  XH|EXTRA-HIGH|X) TASK_DETAIL="XH" ;;
  *)
    echo "ERROR: --task-detail must be L, M, H, or XH (got: $TASK_DETAIL)" >&2
    exit 1
    ;;
esac

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

# Temp files under repo ./tmp by default; override via PLAN_AN_GO_TMP (.env) or env
TMP_DIR="${PLAN_AN_GO_TMP:-$REPO_ROOT/tmp}"
mkdir -p "$TMP_DIR"

# Require either an input file or --prompt
if [ -z "$USER_PROMPT" ] && [ -z "$INPUT_FILE" ]; then
  echo "Usage: $0 [--in PATH] [--out PATH] [--task-detail L|M|H|XH] [--cli ...] (PRD.md | other file)" >&2
  echo "   or: $0 [options] --in PATH   (explicit input file)" >&2
  echo "   or: $0 [options] --prompt=\"Your planning request here\"" >&2
  echo "Default output: ./PLAN.md. Default --task-detail: M (medium)." >&2
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

# Task granularity: inject instructions based on --task-detail (L=low, M=medium, H=high, XH=extra high)
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "TASK GRANULARITY (obey this level for how many and how fine-grained tasks are)" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
case "$TASK_DETAIL" in
  L)
    echo "- **Level: LOW (L).** Use fewer, coarser tasks. Group related work into single tasks (e.g. \"Implement API routes and validation\" rather than one task per route). Aim for 1–4 tasks per milestone. Prefer broader descriptions; avoid subtasks unless necessary." >> "$temp_prompt"
    ;;
  M)
    echo "- **Level: MEDIUM (M).** Use granular but not exhaustive tasks. Each task is one concrete step; use subtasks (e.g. M1:2.1, M1:2.2) when a step has multiple parts. Aim for 2–6 tasks per milestone. Include file paths or artifact names where helpful." >> "$temp_prompt"
    ;;
  H)
    echo "- **Level: HIGH (H).** Use more granular tasks. Break each logical step into smaller tasks; include file paths and concrete steps; use subtasks liberally. Aim for 4–10+ tasks per milestone where appropriate. Task descriptions should be specific enough that an implementer knows exactly what to do." >> "$temp_prompt"
    ;;
  XH)
    echo "- **Level: EXTRA HIGH (XH).** Use maximum detail. Every actionable step is its own task. Include exact paths, env vars, and acceptance criteria in task lines where helpful; use subtasks liberally (e.g. M1:2.1, M1:2.2, M1:2.3). Prefer more milestones and many small tasks over fewer large ones. An implementer should be able to complete each task in a single focused change." >> "$temp_prompt"
    ;;
  *) ;;
esac
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

# Spinner while CLI runs: show animated loader and elapsed time on stderr
planner_spinner() {
  local pid=$1
  local msg=$2
  local frames=("[=    ]" "[ =   ]" "[  =  ]" "[   = ]" "[    =]" "[   = ]" "[  =  ]" "[ =   ]")
  local i=0
  local start elapsed
  start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$(($(date +%s) - start))
    printf "\r  %s %s (%ds)    " "${frames[i % 8]}" "$msg" "$elapsed" >&2
    i=$((i + 1))
    sleep 0.15
  done
  elapsed=$(($(date +%s) - start))
  printf "\r  ✓ %s (%ds)                \n" "$msg" "$elapsed" >&2
}

printf '\n' >&2
echo "--------------" >&2
printf '\n' >&2
echo "[planner] Generating plan with $CLI_BIN (task-detail: $TASK_DETAIL)..." >&2

set +e
if [ "$CLI_BIN" = "codex" ]; then
  codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_out" 2> "$temp_err" &
else
  "$CLI_BIN" "${CLI_ARGS[@]}" -p "@$temp_prompt" > "$temp_out" 2> "$temp_err" &
fi
cli_pid=$!
planner_spinner "$cli_pid" "[planner] Generating plan with $CLI_BIN (task-detail: $TASK_DETAIL)..."
wait "$cli_pid"
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
  echo "ERROR: CLI exited with code $exit_code" >&2
  if [ -s "$temp_err" ]; then
    echo "--- CLI stderr ---" >&2
    grep -v '^\[Paste:' "$temp_err" 2>/dev/null | grep -v '^\[Test:' 2>/dev/null | cat >&2 || cat "$temp_err" >&2
  fi
  if [ -s "$temp_out" ]; then
    echo "--- CLI stdout (last 40 lines) ---" >&2
    tail -40 "$temp_out" >&2
  fi
  exit $exit_code
fi

if [ -s "$temp_err" ]; then
  grep -v '^\[Paste:' "$temp_err" 2>/dev/null | grep -v '^\[Test:' 2>/dev/null | cat >&2 || cat "$temp_err" >&2
fi

# Write output to target file
mkdir -p "$(dirname "$OUT_FILE")"
cat "$temp_out" > "$OUT_FILE"
echo "[planner] Wrote PLAN to $OUT_FILE" >&2

# Optional: run plan check if available
plan_check="$SCRIPT_DIR/plan-an-go-plan-check.sh"
if [ -f "$plan_check" ] && [ -x "$plan_check" ]; then
  "$plan_check" "$OUT_FILE" || true
fi

exit 0
