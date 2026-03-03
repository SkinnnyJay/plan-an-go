#!/bin/bash
# plan-an-go.sh — AGENT 1: Implementation Agent
# Usage: ./plan-an-go.sh [--cli claude|codex|cursor-agent] [--cli-flags "<flags>"] (called by plan-an-go-forever.sh orchestrator)
#
# This agent focuses ONLY on implementing ONE task from the PRD.
# Validation is handled by a separate agent (plan-an-go-validate.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get PRD file from environment or use default
PRD_FILE="${PRD_FILE:-PRD.md}"
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"

for arg in "$@"; do
  case $arg in
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --cli)
      # Handle --cli <value> format (next arg is the CLI)
      # This will be handled in the next iteration
      ;;
    --cli-flags)
      # Handle --cli-flags <value> format (next arg is the flags)
      # This will be handled in the next iteration
      ;;
    *)
      if [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

if [ "$CLI_BIN" != "claude" ] && [ "$CLI_BIN" != "codex" ] && [ "$CLI_BIN" != "cursor-agent" ]; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: --cli must be 'claude', 'codex', or 'cursor-agent' (got: $CLI_BIN)"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$PRD_FILE" ]; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: PRD file not found: $PRD_FILE"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

if [ ! -s "$PRD_FILE" ]; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: PRD file is empty: $PRD_FILE"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

# Validate selected CLI is available
if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "------START: IMPLEMENTER------"
  echo "ERROR: '$CLI_BIN' CLI not found in PATH"
  echo "VERDICT: FAILED"
  echo "------END: IMPLEMENTER------"
  exit 1
fi

# Create progress.txt if missing
[ ! -f "progress.txt" ] && echo "# Progress Log" > progress.txt

# Extract incomplete tasks to reduce token usage
EXTRACTED_PRD=$(mktemp)
trap 'rm -f "$EXTRACTED_PRD" "$temp_file" "$temp_err" "$temp_prompt"' EXIT
"$SCRIPT_DIR/scripts/extract-incomplete-tasks.sh" "$PRD_FILE" "$EXTRACTED_PRD" 2>/dev/null || {
  echo "Warning: Failed to extract incomplete tasks, using full PRD" >&2
  cp "$PRD_FILE" "$EXTRACTED_PRD"
}

# Run implementation agent
temp_file=$(mktemp)
temp_err=$(mktemp)
temp_prompt=$(mktemp)

# Build prompt in temp file using heredoc (safer for special characters)
cat > "$temp_prompt" << 'STATIC_PROMPT'
You are AGENT 1: THE IMPLEMENTER. Your job is to implement ONE task from the PRD using a structured plan-think-research-distill-execute-validate workflow. A separate validation agent will also audit your work.

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
   - Consider how this task fits the milestone and PRD.

3. RESEARCH
   - Use the PRD and any attached context as your research base.
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
   - Only after validation passes: mark the task as done in the PRD file (path below): change [  ] to [x] or [ x] on that line; commit; update progress.txt.

Then output your report in the required format below.

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════════════

------START: IMPLEMENTER------
MILESTONE: [milestone or phase from PRD]
FEATURE: [Task ID]
PLAN: [1–2 line summary]
SUB-TASKS DONE: [list]
FILES: [created/modified files]
VALIDATION: [commands run and result, e.g. npm run test = pass]
COMMIT: [hash] - [message]
------END: IMPLEMENTER------

═══════════════════════════════════════════════════════════════════════════════
PRD FILE TO UPDATE (edit this file: mark done = change [  ] to [x] or [ x] on the task line)
═══════════════════════════════════════════════════════════════════════════════
STATIC_PROMPT
echo "$PRD_FILE" >> "$temp_prompt"
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PRD CONTENT (incomplete tasks only)" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
# Append the PRD content and progress
cat "$EXTRACTED_PRD" >> "$temp_prompt"
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PROGRESS LOG" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
cat "progress.txt" >> "$temp_prompt"

# Streaming output colors (ANSI escape codes)
# Uncomment your preferred background color:
STREAM_BG="\033[48;5;236m"  # Dark gray (default - subtle, good readability)
# STREAM_BG="\033[48;5;17m"   # Dark blue
# STREAM_BG="\033[48;5;22m"   # Dark green
# STREAM_BG="\033[100m"       # Bright black
STREAM_RESET="\033[0m"

# Check if streaming is enabled (from parent script or environment)
STREAM_OUTPUT="${STREAM_OUTPUT:-false}"

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

# Codex: -p is config profile, not prompt. Use "codex exec" and stdin for prompt.
# Claude/cursor-agent: -p @file reads prompt from file.
if [ "$STREAM_OUTPUT" = "true" ]; then
  # Streaming mode: display output in real-time with colored background
  printf "%b" "${STREAM_BG}" >/dev/tty 2>/dev/null || true
  if [ "$CLI_BIN" = "codex" ]; then
    codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" 2>&1 | tee "$temp_file"
  else
    "$CLI_BIN" "${CLI_ARGS[@]}" -p "@$temp_prompt" 2>&1 | tee "$temp_file"
  fi
  exit_code=${PIPESTATUS[0]}
  printf "%b" "${STREAM_RESET}" >/dev/tty 2>/dev/null || true
else
  # Batch mode: capture all output, display after
  if [ "$CLI_BIN" = "codex" ]; then
    codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_file" 2> "$temp_err"
  else
    "$CLI_BIN" "${CLI_ARGS[@]}" -p "@$temp_prompt" > "$temp_file" 2> "$temp_err"
  fi
  exit_code=$?

  # Output result
  if [ -s "$temp_file" ]; then
    cat "$temp_file"
  fi

  # Output errors to stderr if any
  if [ -s "$temp_err" ]; then
    grep -v '^\[Paste:' "$temp_err" 2>/dev/null | grep -v '^\[Test:' 2>/dev/null | cat >&2 || cat "$temp_err" >&2
  fi
fi

# Pass through exit code
exit $exit_code
