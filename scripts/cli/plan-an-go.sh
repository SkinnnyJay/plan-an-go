#!/bin/bash
# plan-an-go.sh — AGENT 1: Implementation Agent
# Usage: ./plan-an-go.sh [--workspace DIR] [--cli claude|cline|copilot|codex|cursor-agent|droid|gemini|goose|kiro|opencode] [--cli-flags "<flags>"] (called by plan-an-go-forever.sh orchestrator)
#
# This agent focuses ONLY on implementing ONE task from the plan.
# Validation is handled by a separate agent (plan-an-go-validate.sh).

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get plan file and workspace from environment or use default
PLAN_FILE="${PLAN_FILE:-PLAN.md}"
WORKSPACE="${PLAN_AN_GO_WORKSPACE:-}"
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
PLAN_AN_GO_STRICT="${PLAN_AN_GO_STRICT:-false}"

PREV_ARG=""
for arg in "$@"; do
  case $arg in
    --workspace=*)
      WORKSPACE="${arg#*=}"
      ;;
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --strict)
      PLAN_AN_GO_STRICT=true
      ;;
    --workspace) ;;
    --cli) ;;
    --cli-flags) ;;
    *)
      if [ "${PREV_ARG}" = "--workspace" ]; then
        WORKSPACE="$arg"
      elif [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done
export PLAN_AN_GO_STRICT

# Resolve CLI flags: use PLAN_AN_GO_CLI_FLAGS if set, else per-CLI vars
if [ -z "$CLI_FLAGS" ]; then
  case "$CLI_BIN" in
    claude) CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    cline) CLI_FLAGS="${PLAN_AN_GO_CLINE_FLAGS:-}" ;;
    codex) CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    copilot) CLI_FLAGS="${PLAN_AN_GO_COPILOT_FLAGS:-}" ;;
    cursor-agent) CLI_FLAGS="${PLAN_AN_GO_CURSOR_AGENT_FLAGS:-}" ;;
    droid) CLI_FLAGS="${PLAN_AN_GO_DROID_FLAGS:-}" ;;
    gemini) CLI_FLAGS="${PLAN_AN_GO_GEMINI_FLAGS:-}" ;;
    goose) CLI_FLAGS="${PLAN_AN_GO_GOOSE_FLAGS:-}" ;;
    kiro) CLI_FLAGS="${PLAN_AN_GO_KIRO_FLAGS:-}" ;;
    opencode) CLI_FLAGS="${PLAN_AN_GO_OPENCODE_FLAGS:-}" ;;
    *) ;;
  esac
fi

# Change to workspace directory when specified (for standalone runs)
if [ -n "$WORKSPACE" ]; then
  WORKSPACE_ABS="$(cd "$WORKSPACE" && pwd)"
  cd "$WORKSPACE_ABS" || {
    echo "ERROR: Cannot cd to workspace: $WORKSPACE" >&2
    exit 1
  }
  # Resolve PLAN_FILE relative to workspace if it was relative
  if [[ "$PLAN_FILE" != /* ]]; then
    PLAN_FILE="$WORKSPACE_ABS/$PLAN_FILE"
  fi
fi

# All pipeline output under ./tmp by default (unique temp files and standard names).
# When PLAN_AN_GO_TMP is set (e.g. in .env), use a workspace-unique subdir so progress/history/tail
# do not collide across different workspaces.
TMP_BASE="${PLAN_AN_GO_TMP:-./tmp}"
if [ -n "${PLAN_AN_GO_TMP:-}" ]; then
  ROOT_FOR_HASH="${WORKSPACE_ABS:-$(pwd)}"
  WORKSPACE_ID=$(echo -n "$ROOT_FOR_HASH" | openssl dgst -sha256 2>/dev/null | awk '{print $2}' | cut -c1-8)
  [ -z "$WORKSPACE_ID" ] && WORKSPACE_ID="default"
  TMP_DIR="$TMP_BASE/$WORKSPACE_ID"
else
  TMP_DIR="$TMP_BASE"
fi
mkdir -p "$TMP_DIR"
PROGRESS_FILE="$TMP_DIR/progress.log"

case "$CLI_BIN" in
  claude | cline | copilot | codex | cursor-agent | droid | gemini | goose | kiro | opencode) ;;
  *)
    echo "------START: IMPLEMENTER------"
    echo "ERROR: --cli must be 'claude', 'cline', 'copilot', 'codex', 'cursor-agent', 'droid', 'gemini', 'goose', 'kiro', or 'opencode' (got: $CLI_BIN)"
    echo "VERDICT: FAILED"
    echo "------END: IMPLEMENTER------"
    exit 1
    ;;
esac

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$PLAN_FILE" ]; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: Plan file not found: $PLAN_FILE"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

if [ ! -s "$PLAN_FILE" ]; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: Plan file is empty: $PLAN_FILE"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

# When PLAN_AN_GO_STRICT is true, require <work>-compliant plan
if [ "${PLAN_AN_GO_STRICT:-false}" = "true" ]; then
  WORK_SCRIPT="$SCRIPT_DIR/scripts/plan-work-section.sh"
  if [ -f "$WORK_SCRIPT" ] && ! bash "$WORK_SCRIPT" compliant "$PLAN_FILE" 2>/dev/null; then
    echo "------START: IMPLEMENTER------"
    echo "ERROR: Plan is not <work>-compliant (required when PLAN_AN_GO_STRICT=true). Wrap milestones and tasks in <work>...</work>."
    echo "VERDICT: FAILED"
    echo "------END: IMPLEMENTER------"
    exit 1
  fi
fi

# Validate selected CLI is available
if ! command -v "$CLI_BIN" &>/dev/null; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: '$CLI_BIN' CLI not found in PATH"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

# Create progress log under TMP_DIR if missing (PLAN_AN_GO_TMP defaults to ./tmp)
[ ! -f "$PROGRESS_FILE" ] && echo "# Progress Log" >"$PROGRESS_FILE"

# Extract incomplete tasks to reduce token usage (when PLAN_AN_GO_AGENT_ID is set, only that agent's task is included)
EXTRACTED_PLAN=$(mktemp "$TMP_DIR/extract.XXXXXX")
# shellcheck disable=SC2329
cleanup() {
  # shellcheck disable=SC2317
  [ -n "${EXTRACTED_PLAN:-}" ] && rm -f "$EXTRACTED_PLAN"
  [ -n "${temp_file:-}" ] && rm -f "$temp_file"
  [ -n "${temp_err:-}" ] && rm -f "$temp_err"
  [ -n "${temp_prompt:-}" ] && rm -f "$temp_prompt"
}
trap cleanup EXIT
"$SCRIPT_DIR/scripts/extract-incomplete-tasks.sh" "$PLAN_FILE" "$EXTRACTED_PLAN" "${PLAN_AN_GO_AGENT_ID:-}" 2>/dev/null || {
  echo "Warning: Failed to extract incomplete tasks, using full plan" >&2
  cp "$PLAN_FILE" "$EXTRACTED_PLAN"
}

# Temp files under tmp/
temp_file=$(mktemp "$TMP_DIR/impl.XXXXXX")
temp_err=$(mktemp "$TMP_DIR/impl-err.XXXXXX")
temp_prompt=$(mktemp "$TMP_DIR/impl-prompt.XXXXXX")

# Build prompt in temp file using heredoc (safer for special characters)
cat >"$temp_prompt" <<'STATIC_PROMPT'
You are AGENT 1: THE IMPLEMENTER. Your job is to implement ONE task from the plan using a structured plan-think-research-distill-execute-validate workflow. A separate validation agent will also audit your work.

═══════════════════════════════════════════════════════════════════════════════
CRITICAL RULES
═══════════════════════════════════════════════════════════════════════════════
- Implement ONE task completely - no shortcuts, stubs, or approximations
- Do NOT mark the task [x] until step 7 (Validate) passes
- Do NOT skip tasks claiming "already implemented" without proof
- Output EVERYTHING the validator needs to verify your work
- All work must be repeatable: document steps so the same outcome can be reproduced
- If you have access to sub-agents (e.g. Cursor mcp_task): delegate independent sub-tasks to them to speed up work; otherwise perform all sub-tasks yourself
- DO NOT CONTINUE to the next task. After your report, STOP IMMEDIATELY.
- If all tasks are complete, output that and STOP IMMEDIATELY.

═══════════════════════════════════════════════════════════════════════════
MANDATORY 7-STEP WORKFLOW (do not skip steps)
═══════════════════════════════════════════════════════════════════════════
Before writing code, reflect on the MILESTONE and the TASK. Then:

1. PLAN
   - Identify the milestone and the first incomplete task [ ].
   - State scope, acceptance criteria, and definition of done.

2. THINK
   - Reason about approach, risks, dependencies, and edge cases.
   - Consider how this task fits the milestone and plan.

3. RESEARCH
   - Use the plan and any attached context as your research base.
   - Identify relevant files, patterns, and constraints (e.g. constants, logging, tests).

4. DISTIL
   - One concise summary: approach, key files, and success criteria.
   - List any assumptions you are making.

5. SUB-TASKS
   - Break the task into ordered sub-tasks (numbered).
   - Mark which sub-tasks can run in parallel if sub-agents are available.

6. WORK (with sub-agents if possible)
   - Execute each sub-task. If you have sub-agents (e.g. explore, generalPurpose, test-runner, verifier), delegate:
     - Research/exploration to an explore or researcher sub-agent
     - Independent implementation sub-tasks to generalPurpose or specialist sub-agents
     - Tests to test-runner, verification to verifier
   - If you do not have sub-agents, perform all sub-tasks yourself in order.
   - Ensure all work is repeatable (document commands and steps).

7. VALIDATE AND QUANTIFY BEFORE CHECK-OFF
   - Run relevant tests and commands (e.g. npm run check, npm run typecheck, npm run test).
   - Verify every acceptance criterion is met; confirm nothing is forgotten or missed.
   - Only after validation passes: mark the task as done in the plan file (path below): change [  ] to [x] or [ x] on that line; then commit (unless COMMIT SKIP below applies); update the progress log at the path shown in PROGRESS LOG section below.

Then output your report in the required format below.

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════════════

------START: IMPLEMENTER------
MILESTONE: [milestone or phase from plan]
FEATURE: [Task ID]
PLAN: [1–2 line summary]
SUB-TASKS DONE: [list]
FILES: [created/modified files]
VALIDATION: [commands run and result, e.g. npm run test = pass]
COMMIT: [hash] - [message]  (or "COMMIT: skipped (reason)" if commit was skipped or failed)
------END: IMPLEMENTER------

═══════════════════════════════════════════════════════════════════════════════
PLAN FILE TO UPDATE (edit this file: mark done = change [  ] to [x] or [ x] on the task line)
═══════════════════════════════════════════════════════════════════════════════
STATIC_PROMPT
{
  echo "$PLAN_FILE"
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "PLAN CONTENT (incomplete tasks only)"
} >>"$temp_prompt"
if [ -n "${PLAN_AN_GO_AGENT_ID:-}" ]; then
  echo "Implement the ONLY task below (your assigned task, marked [IN_PROGRESS]:[${PLAN_AN_GO_AGENT_ID}]). Do not pick any other task." >>"$temp_prompt"
else
  echo "Implement the FIRST task in the list below (the first line starting with \"- [ ] -\"); do not pick a later task." >>"$temp_prompt"
fi
{
  echo "═══════════════════════════════════════════════════════════════════════════════"
  cat "$EXTRACTED_PLAN"
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════════════"
  echo "PROGRESS LOG (update this file when marking task done): $PROGRESS_FILE"
  echo "ARTIFACT DIRECTORY: $TMP_DIR"
  echo "  Write ALL task output/completion files UNDER this directory (e.g. $TMP_DIR/task-M1-1-completed.log). Do NOT create task-*-completed.log or task-*-output.log in the workspace root."
} >>"$temp_prompt"
if [ -n "${PLAN_AN_GO_SKIP_COMMIT:-}" ]; then
  {
    echo ""
    echo "COMMIT SKIP: Do NOT run git add or git commit (workspace is under tmp/; repo .git may be unwritable). In your report use: COMMIT: skipped (workspace under tmp)"
  } >>"$temp_prompt"
fi
{
  echo "═══════════════════════════════════════════════════════════════════════════════"
  cat "$PROGRESS_FILE"
} >>"$temp_prompt"

# Streaming output colors (ANSI escape codes)
# Uncomment your preferred background color:
STREAM_BG="\033[48;5;236m" # Dark gray (default - subtle, good readability)
# STREAM_BG="\033[48;5;17m"   # Dark blue
# STREAM_BG="\033[48;5;22m"   # Dark green
# STREAM_BG="\033[100m"       # Bright black
STREAM_RESET="\033[0m"

# Check if streaming is enabled (from parent script or environment)
STREAM_OUTPUT="${PLAN_AN_GO_STREAM_OUTPUT:-${STREAM_OUTPUT:-false}}"

CLAUDE_MODEL="${PLAN_AN_GO_CLAUDE_MODEL:-claude-sonnet-4-20250514}"
CODEX_MODEL="${PLAN_AN_GO_CODEX_MODEL:-}"
DROID_AUTO="${PLAN_AN_GO_DROID_AUTO:-high}"
GEMINI_MODEL="${PLAN_AN_GO_GEMINI_MODEL:-gemini-2.5-flash}"
OPENCODE_MODEL="${PLAN_AN_GO_OPENCODE_MODEL:-}"
CLI_ARGS=()
if [ "$CLI_BIN" = "claude" ]; then
  CLI_ARGS=(--model "$CLAUDE_MODEL" --dangerously-skip-permissions)
elif [ "$CLI_BIN" = "cline" ]; then
  CLI_ARGS=(-y)
elif [ "$CLI_BIN" = "codex" ]; then
  # Allow implementer to write files (plan file, code, $PROGRESS_FILE). Without this, Codex
  # may run in read-only sandbox and report "blocked by read-only sandbox".
  # codex exec only accepts --sandbox (not --ask-for-approval). Use --full-auto for
  # low-friction automatic execution (workspace-write + approval on-failure).
  CLI_ARGS=(--full-auto)
  [ -n "$CODEX_MODEL" ] && CLI_ARGS+=(--model "$CODEX_MODEL")
elif [ "$CLI_BIN" = "copilot" ]; then
  CLI_ARGS=()
elif [ "$CLI_BIN" = "cursor-agent" ]; then
  # Prompt is passed as positional argument (escaped later); --print for non-interactive.
  CLI_ARGS=(--trust --print)
elif [ "$CLI_BIN" = "droid" ]; then
  CLI_ARGS=(exec --auto "$DROID_AUTO")
elif [ "$CLI_BIN" = "gemini" ]; then
  CLI_ARGS=(--yolo -m "$GEMINI_MODEL")
elif [ "$CLI_BIN" = "goose" ]; then
  CLI_ARGS=()
elif [ "$CLI_BIN" = "kiro" ]; then
  CLI_ARGS=(chat --no-interactive)
elif [ "$CLI_BIN" = "opencode" ]; then
  CLI_ARGS=(run)
  [ -n "$OPENCODE_MODEL" ] && CLI_ARGS+=(--model "$OPENCODE_MODEL")
fi
if [ -n "$CLI_FLAGS" ]; then
  read -r -a EXTRA_CLI_ARGS <<<"$CLI_FLAGS"
  CLI_ARGS+=("${EXTRA_CLI_ARGS[@]}")
fi

# Show clean header (version + implementer + timestamp)
PLAN_AN_GO_VERSION="1.0.0"
PKG_JSON="$(cd "$SCRIPT_DIR/../.." && pwd)/package.json"
if [ -f "$PKG_JSON" ] && command -v node &>/dev/null; then
  _v=$(node -p "require('$PKG_JSON').version" 2>/dev/null) && [ -n "$_v" ] && PLAN_AN_GO_VERSION="$_v"
fi
echo "plan-an-go $PLAN_AN_GO_VERSION · implementer · $(date '+%Y-%m-%d %H:%M:%S')" >&2

# Pass prompt via stdin for codex/droid/others. cursor-agent (and kiro, opencode) require the prompt as a positional argument; escape " and \ so embedding in the command is safe.
# Use set +e so we always capture exit code and show CLI output/errors before exiting.
exit_code=0
set +e
PROMPT_FOR_ARG=""
if [ "$CLI_BIN" = "cursor-agent" ] || [ "$CLI_BIN" = "kiro" ] || [ "$CLI_BIN" = "opencode" ]; then
  PROMPT_FOR_ARG=$(cat "$temp_prompt")
  PROMPT_FOR_ARG="${PROMPT_FOR_ARG//\\/\\\\}"
  PROMPT_FOR_ARG="${PROMPT_FOR_ARG//\"/\\\"}"
fi
if [ "$STREAM_OUTPUT" = "true" ]; then
  echo "[implementer] Running $CLI_BIN (streaming)..." >&2
  printf "%b" "${STREAM_BG}" >/dev/tty 2>/dev/null || true
  if [ "$CLI_BIN" = "codex" ]; then
    codex exec "${CLI_ARGS[@]}" - <"$temp_prompt" 2>&1 | tee "$temp_file"
  elif [ "$CLI_BIN" = "droid" ]; then
    droid "${CLI_ARGS[@]}" -f "$temp_prompt" 2>&1 | tee "$temp_file"
  elif [ "$CLI_BIN" = "kiro" ]; then
    kiro "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" 2>&1 | tee "$temp_file"
  elif [ "$CLI_BIN" = "opencode" ]; then
    opencode "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" 2>&1 | tee "$temp_file"
  elif [ "$CLI_BIN" = "cursor-agent" ]; then
    "$CLI_BIN" "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" 2>&1 | tee "$temp_file"
  else
    "$CLI_BIN" "${CLI_ARGS[@]}" - <"$temp_prompt" 2>&1 | tee "$temp_file"
  fi
  exit_code=${PIPESTATUS[0]}
  printf "%b" "${STREAM_RESET}" >/dev/tty 2>/dev/null || true
else
  echo "[implementer] Running $CLI_BIN..." >&2
  if [ "$CLI_BIN" = "codex" ]; then
    codex exec "${CLI_ARGS[@]}" - <"$temp_prompt" >"$temp_file" 2>"$temp_err"
  elif [ "$CLI_BIN" = "droid" ]; then
    droid "${CLI_ARGS[@]}" -f "$temp_prompt" >"$temp_file" 2>"$temp_err"
  elif [ "$CLI_BIN" = "kiro" ]; then
    kiro "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" >"$temp_file" 2>"$temp_err"
  elif [ "$CLI_BIN" = "opencode" ]; then
    opencode "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" >"$temp_file" 2>"$temp_err"
  elif [ "$CLI_BIN" = "cursor-agent" ]; then
    "$CLI_BIN" "${CLI_ARGS[@]}" "$PROMPT_FOR_ARG" >"$temp_file" 2>"$temp_err"
  else
    "$CLI_BIN" "${CLI_ARGS[@]}" - <"$temp_prompt" >"$temp_file" 2>"$temp_err"
  fi
  exit_code=$?
  set -e
  if [ -s "$temp_file" ]; then
    cat "$temp_file"
  fi
  if [ -s "$temp_err" ]; then
    grep -v '^\[Paste:' "$temp_err" 2>/dev/null | grep -v '^\[Test:' 2>/dev/null | cat >&2 || cat "$temp_err" >&2
  fi
fi

# Pass through exit code
exit "$exit_code"
