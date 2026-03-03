#!/bin/bash
# plan-an-go-validate.sh — AGENT 2: Validation Agent
# Usage: ./plan-an-go-validate.sh <implementer_output_file> [--cli claude|codex|cursor-agent] [--cli-flags "<flags>"]
#
# This agent validates work done by the Implementation Agent.
# It audits code, runs tests, checks for shortcuts, and updates the PRD file (see PRD_FILE env / prompt).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPLEMENTER_OUTPUT="${1:-}"

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
  echo "------START: VALIDATOR------"
  echo "ERROR: --cli must be 'claude', 'codex', or 'cursor-agent' (got: $CLI_BIN)"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
# Check implementer output
if [ -z "$IMPLEMENTER_OUTPUT" ] || [ ! -f "$IMPLEMENTER_OUTPUT" ]; then
  echo "------START: VALIDATOR------"
  echo "ERROR: Implementer output file required"
  echo "Usage: ./plan-an-go-validate.sh <implementer_output_file>"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

# Check PRD file
if [ ! -f "$PRD_FILE" ]; then
  echo "------START: VALIDATOR------"
  echo "ERROR: PRD file not found: $PRD_FILE"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

if [ ! -s "$PRD_FILE" ]; then
  echo "------START: VALIDATOR------"
  echo "ERROR: PRD file is empty: $PRD_FILE"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

# Validate selected CLI is available
if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "------START: VALIDATOR------"
  echo "ERROR: '$CLI_BIN' CLI not found in PATH"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

# Get absolute path for the implementer output file
IMPLEMENTER_OUTPUT_ABS="$(cd "$(dirname "$IMPLEMENTER_OUTPUT")" && pwd)/$(basename "$IMPLEMENTER_OUTPUT")"

# Extract incomplete tasks to reduce token usage
EXTRACTED_PRD=$(mktemp)
trap 'rm -f "$EXTRACTED_PRD" "$temp_file" "$temp_err" "$temp_prompt"' EXIT
"$SCRIPT_DIR/scripts/extract-incomplete-tasks.sh" "$PRD_FILE" "$EXTRACTED_PRD" 2>/dev/null || {
  echo "Warning: Failed to extract incomplete tasks, using full PRD" >&2
  cp "$PRD_FILE" "$EXTRACTED_PRD"
}

# Run validation agent
temp_file=$(mktemp)
temp_err=$(mktemp)
temp_prompt=$(mktemp)

# Build prompt in temp file using heredoc (safer for special characters)
cat > "$temp_prompt" << 'STATIC_PROMPT'
You are AGENT 2: THE VALIDATOR. Your job is to audit the implementer's work and ensure it is validated, quantified, and repeatable.

═══════════════════════════════════════════════════════════════════════════════
YOUR MISSION: FIND PROBLEMS AND ENSURE COMPLETENESS
═══════════════════════════════════════════════════════════════════════════════
- Code that doesn't match PRD requirements
- Tests that are mocked or hardcoded to pass
- Missing functionality claimed as complete
- Shortcuts, stubs, or approximations
- Anything forgotten or missed (checklist vs PRD acceptance criteria)
- Work that is not repeatable (missing steps, undocumented commands)

═══════════════════════════════════════════════════════════════════════════════
VALIDATION WORKFLOW
═══════════════════════════════════════════════════════════════════════════════
1. VERIFY CODE EXISTS - Check files the implementer claims to have created/modified
2. RUN TESTS INDEPENDENTLY - Run the same tests + additional tests (e.g. npm run check, npm run typecheck, npm run test)
3. QUANTIFY COMPLETION - For the task, list each acceptance criterion and state MET / NOT MET
4. NOTHING FORGOTTEN - Cross-check PRD task description and any sub-tasks; confirm no item is missed
5. REPEATABILITY - Confirm steps/commands are documented so the work can be reproduced; flag if not
6. CALCULATE CONFIDENCE (0-10): code exists + criteria met + tests pass + no shortcuts + all criteria quantified + repeatable

TAKE ACTION:
- If confidence >= 8/10: Keep task done in the PRD file (path below): ensure the task line has [x] or [ x], not [  ]; update progress.txt
- If confidence < 8/10: Revert: change [x] or [ x] back to [  ] (two spaces) on that task line; document issues

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════════════

------START: VALIDATOR------
MODE: TASK_VALIDATION
FEATURE: [Task ID]
CONFIDENCE SCORE: [X/10]
CRITERIA: [each PRD criterion → MET/NOT MET]
VERDICT: APPROVED / NEEDS_WORK
REPEATABLE: YES / NO [and if NO, what is missing]
ACTION: [Marked [x] / Reverted to [ ] / No change]
ISSUES: [List issues or "None - approved"]
------END: VALIDATOR------

FINAL STATUS:
- If APPROVED and all done: <status>ALL_TASKS_COMPLETE</status>
- If NEEDS_WORK: <status>NEEDS_CORRECTION</status>
- If APPROVED but more tasks: <status>CONTINUE</status>

═══════════════════════════════════════════════════════════════════════════════
IMPLEMENTER OUTPUT (what they claim to have done)
═══════════════════════════════════════════════════════════════════════════════
STATIC_PROMPT

# Append implementer output
cat "$IMPLEMENTER_OUTPUT_ABS" >> "$temp_prompt"

# Append PRD file path and content
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PRD FILE TO UPDATE (done = [x] or [ x] on task line; revert = change back to [  ])" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "$PRD_FILE" >> "$temp_prompt"
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PRD CONTENT (incomplete tasks)" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
cat "$EXTRACTED_PRD" >> "$temp_prompt"

# Append progress
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
