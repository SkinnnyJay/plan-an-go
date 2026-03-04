#!/bin/bash
# plan-an-go-validate.sh — AGENT 2: Validation Agent
# Usage: ./plan-an-go-validate.sh <implementer_output_file> [--workspace DIR] [--cli claude|codex|cursor-agent] [--cli-flags "<flags>"]
#
# This agent validates work done by the Implementation Agent.
# It audits code, runs tests, checks for shortcuts, and updates the plan file (see PLAN_FILE env / prompt).

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPLEMENTER_OUTPUT="${1:-}"

# Get plan file and workspace from environment or use default
PLAN_FILE="${PLAN_FILE:-PLAN.md}"
WORKSPACE="${PLAN_AN_GO_WORKSPACE:-}"
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"

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
    --workspace)
      ;;
    --cli)
      ;;
    --cli-flags)
      ;;
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

# Resolve CLI flags: use PLAN_AN_GO_CLI_FLAGS if set, else per-CLI vars
if [ -z "$CLI_FLAGS" ]; then
  case "$CLI_BIN" in
    claude) CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    codex)  CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    *)      ;;
  esac
fi

# Change to workspace directory when specified (for standalone runs)
if [ -n "$WORKSPACE" ]; then
  # Resolve implementer output to absolute path before cd (so relative path still works)
  if [ -n "$IMPLEMENTER_OUTPUT" ] && [[ "$IMPLEMENTER_OUTPUT" != /* ]]; then
    IMPLEMENTER_OUTPUT="$(cd "$(dirname "$IMPLEMENTER_OUTPUT")" 2>/dev/null && pwd)/$(basename "$IMPLEMENTER_OUTPUT")"
  fi
  WORKSPACE_ABS="$(cd "$WORKSPACE" && pwd)"
  cd "$WORKSPACE_ABS" || { echo "ERROR: Cannot cd to workspace: $WORKSPACE" >&2; exit 1; }
  if [[ "$PLAN_FILE" != /* ]]; then
    PLAN_FILE="$WORKSPACE_ABS/$PLAN_FILE"
  fi
fi

# Pipeline output under ./tmp by default.
# When PLAN_AN_GO_TMP is set (e.g. in .env), use a workspace-unique subdir so temp files
# do not collide across different workspaces.
TMP_BASE="${PLAN_AN_GO_TMP:-./tmp}"
if [ -n "$WORKSPACE" ]; then
  ROOT_FOR_HASH="$(cd "$WORKSPACE" && pwd)"
else
  ROOT_FOR_HASH="$(pwd)"
fi
if [ -n "${PLAN_AN_GO_TMP:-}" ]; then
  WORKSPACE_ID=$(echo -n "$ROOT_FOR_HASH" | openssl dgst -sha256 2>/dev/null | awk '{print $2}' | cut -c1-8)
  [ -z "$WORKSPACE_ID" ] && WORKSPACE_ID="default"
  TMP_DIR="$TMP_BASE/$WORKSPACE_ID"
else
  TMP_DIR="$TMP_BASE"
fi
mkdir -p "$TMP_DIR"
PROGRESS_FILE="$TMP_DIR/progress.txt"
[ ! -f "$PROGRESS_FILE" ] && echo "# Progress Log" > "$PROGRESS_FILE"

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

# Check plan file
if [ ! -f "$PLAN_FILE" ]; then
  echo "------START: VALIDATOR------"
  echo "ERROR: Plan file not found: $PLAN_FILE"
  echo "VERDICT: FAILED"
  echo "------END: VALIDATOR------"
  exit 1
fi

if [ ! -s "$PLAN_FILE" ]; then
  echo "------START: VALIDATOR------"
  echo "ERROR: Plan file is empty: $PLAN_FILE"
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
EXTRACTED_PLAN=$(mktemp "$TMP_DIR/validate-extract.XXXXXX")
cleanup() {
  [ -n "${EXTRACTED_PLAN:-}" ] && rm -f "$EXTRACTED_PLAN"
  [ -n "${temp_file:-}" ] && rm -f "$temp_file"
  [ -n "${temp_err:-}" ] && rm -f "$temp_err"
  [ -n "${temp_prompt:-}" ] && rm -f "$temp_prompt"
}
trap cleanup EXIT
"$SCRIPT_DIR/scripts/extract-incomplete-tasks.sh" "$PLAN_FILE" "$EXTRACTED_PLAN" 2>/dev/null || {
  echo "Warning: Failed to extract incomplete tasks, using full plan" >&2
  cp "$PLAN_FILE" "$EXTRACTED_PLAN"
}

# Temp files under tmp/
temp_file=$(mktemp "$TMP_DIR/validator.XXXXXX")
temp_err=$(mktemp "$TMP_DIR/validator-err.XXXXXX")
temp_prompt=$(mktemp "$TMP_DIR/validator-prompt.XXXXXX")

# Build prompt in temp file using heredoc (safer for special characters)
cat > "$temp_prompt" << 'STATIC_PROMPT'
You are AGENT 2: THE VALIDATOR. Your job is to audit the implementer's work and ensure it is validated, quantified, and repeatable.

═══════════════════════════════════════════════════════════════════════════════
YOUR MISSION: FIND PROBLEMS AND ENSURE COMPLETENESS
═══════════════════════════════════════════════════════════════════════════════
- Code that doesn't match plan requirements
- Tests that are mocked or hardcoded to pass
- Missing functionality claimed as complete
- Shortcuts, stubs, or approximations
- Anything forgotten or missed (checklist vs plan acceptance criteria)
- Work that is not repeatable (missing steps, undocumented commands)

═══════════════════════════════════════════════════════════════════════════════
VALIDATION WORKFLOW
═══════════════════════════════════════════════════════════════════════════════
1. VERIFY CODE EXISTS - Check files the implementer claims to have created/modified
2. RUN TESTS INDEPENDENTLY - Run the same tests + additional tests (e.g. npm run check, npm run typecheck, npm run test)
3. QUANTIFY COMPLETION - For the task, list each acceptance criterion and state MET / NOT MET
4. NOTHING FORGOTTEN - Cross-check plan task description and any sub-tasks; confirm no item is missed
5. REPEATABILITY - Confirm steps/commands are documented so the work can be reproduced; flag if not
6. CALCULATE CONFIDENCE (0-10): code exists + criteria met + tests pass + no shortcuts + all criteria quantified + repeatable

TAKE ACTION:
- If confidence >= 8/10: Keep task done in the plan file (path below): ensure the task line has [x] or [ x], not [  ]; update the progress log at the path shown in PROGRESS LOG section below
- If confidence < 8/10: Revert: change [x] or [ x] back to [  ] (two spaces) on that task line; document issues

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════════════

------START: VALIDATOR------
MODE: TASK_VALIDATION
FEATURE: [Task ID]
CONFIDENCE SCORE: [X/10]
CRITERIA: [each plan criterion → MET/NOT MET]
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

# Append plan file path and content
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PLAN FILE TO UPDATE (done = [x] or [ x] on task line; revert = change back to [  ])" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "$PLAN_FILE" >> "$temp_prompt"
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PLAN CONTENT (incomplete tasks)" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
cat "$EXTRACTED_PLAN" >> "$temp_prompt"

# Append progress
echo "" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
echo "PROGRESS LOG (update this file when approving): $PROGRESS_FILE" >> "$temp_prompt"
echo "═══════════════════════════════════════════════════════════════════════════════" >> "$temp_prompt"
cat "$PROGRESS_FILE" >> "$temp_prompt"

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
elif [ "$CLI_BIN" = "codex" ]; then
  CLI_ARGS=(--full-auto)
  [ -n "$CODEX_MODEL" ] && CLI_ARGS+=(--model "$CODEX_MODEL")
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
    "$CLI_BIN" "${CLI_ARGS[@]}" - < "$temp_prompt" 2>&1 | tee "$temp_file"
  fi
  exit_code=${PIPESTATUS[0]}
  printf "%b" "${STREAM_RESET}" >/dev/tty 2>/dev/null || true
else
  # Batch mode: capture all output, display after
  if [ "$CLI_BIN" = "codex" ]; then
    codex exec "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_file" 2> "$temp_err"
  else
    "$CLI_BIN" "${CLI_ARGS[@]}" - < "$temp_prompt" > "$temp_file" 2> "$temp_err"
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
