#!/bin/bash
# plan-an-go-forever.sh — ORCHESTRATOR: Runs Implementer → Validator pipeline
# Usage: ./plan-an-go-forever.sh [parent_loops] [child_loops] [--no-validate] [--no-threads] [--stream] [--no-slack|--slack] [--cli claude|codex|cursor-agent] [--cli-flags "<flags>"]
#
# Implementer uses a 7-step workflow: Plan → Think → Research → Distill → Sub-tasks →
# Work (with sub-agents if available) → Validate & quantify before check-off.
# When run from Cursor, the implementer can delegate to sub-agents (e.g. explore,
# generalPurpose, test-runner, verifier) to accomplish work faster. All work is
# validated and repeatable.
#
# Slack: Loads plan-an-go-slack-update.sh from repo root (post_to_slack, post_to_slack_thread, etc.).
# Use --no-slack to disable Slack entirely; --slack to enable (default: enabled).
# Optional: run ./plan-an-go-file-watch.sh in another terminal to watch repo changes while the pipeline runs.
#
# Arguments:
#   parent_loops   - Number of orchestrator iterations (default: 100)
#   child_loops    - Max LLM API calls per agent invocation (default: 50)
#   --no-validate  - Skip validation step (implementer only mode)
#   --no-threads   - Disable Slack threads (post messages directly to channel)
#   --stream       - Stream LLM output in real-time with gray background
#   --no-slack     - Disable Slack (no sourcing of slack script, no posts)
#   --slack        - Enable Slack (default; overrides env or previous --no-slack)
#   --tail[=FILE]  - Write implementer + validator output to FILE (default: pipeline-tail.log)
#                    so you can "tail -f FILE" in another terminal to see current iteration.
#                    File is overwritten at the start of each iteration.
#   --cli          - LLM CLI to use: claude, codex, or cursor-agent (default: claude)
#   --cli-flags    - Extra flags passed through to the CLI (quoted string)
#
# Examples:
#   ./plan-an-go-forever.sh                    # 100 parent loops, 50 child loops, with validation
#   ./plan-an-go-forever.sh 100 50             # 100 parent loops, 50 child loops, with validation
#   ./plan-an-go-forever.sh 100 50 --no-validate  # Skip validation, implementer only
#   ./plan-an-go-forever.sh --no-threads         # Post updates directly to channel
#   ./plan-an-go-forever.sh --no-slack           # Run without Slack
#   ./plan-an-go-forever.sh --no-validate      # Default loops, skip validation
#   ./plan-an-go-forever.sh --tail              # Write iteration output to pipeline-tail.log; tail -f to watch
#   ./plan-an-go-forever.sh --tail=my.log       # Use my.log for tail output
#   ./plan-an-go-forever.sh --cli codex         # Use codex CLI instead of claude
#   ./plan-an-go-forever.sh --cli cursor-agent  # Use cursor-agent CLI (auto model)
#
# Pipeline per iteration:
#   1. AGENT 1 (Implementer): Plan/Think/Research/Distill → Sub-tasks → Work (sub-agents if available) → Validate → ONE task (up to child_loops calls)
#   2. AGENT 2 (Validator): Audits, quantifies completion, checks repeatability, runs tests, updates PRD (up to child_loops calls)
#      (skipped with --no-validate)
#   3. ORCHESTRATOR: Logs results, posts to Slack, decides next action

#═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════
# Parse arguments - check for --no-validate, --no-threads, --prd, --stream, --tail, --no-slack/--slack, --cli
SKIP_VALIDATION=false
STREAM_OUTPUT=false
PRD_FILE="PRD.md"
TAIL_LOG=""
USE_SLACK="${USE_SLACK:-true}"
SLACK_USE_THREADS="${SLACK_USE_THREADS:-true}"
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
POSITIONAL_ARGS=()
for arg in "$@"; do
  case $arg in
    --no-validate)
      SKIP_VALIDATION=true
      ;;
    --no-threads|--no-thread|--simple-slack)
      SLACK_USE_THREADS=false
      ;;
    --no-slack)
      USE_SLACK=false
      ;;
    --slack)
      USE_SLACK=true
      ;;
    --stream)
      STREAM_OUTPUT=true
      ;;
    --tail)
      TAIL_LOG="pipeline-tail.log"
      ;;
    --tail=*)
      TAIL_LOG="${arg#*=}"
      ;;
    --prd=*)
      PRD_FILE="${arg#*=}"
      ;;
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --prd)
      # Handle --prd <file> format (next arg is the file)
      # This will be handled in the next iteration
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
      # Check if previous arg was --prd
      if [ "${PREV_ARG}" = "--prd" ]; then
        PRD_FILE="$arg"
      elif [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      else
        POSITIONAL_ARGS+=("$arg")
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

# Export for child scripts
export STREAM_OUTPUT
export USE_SLACK
export PLAN_AN_GO_CLI="$CLI_BIN"
export PLAN_AN_GO_CLI_FLAGS="$CLI_FLAGS"

MAX_ITERATIONS=${POSITIONAL_ARGS[0]:-100}
MAX_CHILD_LOOPS=${POSITIONAL_ARGS[1]:-50}
LOG_FILE="history.log"

# Sound notification: plays when iteration completes
SOUND_ENABLED=true
SOUND_FILE="/System/Library/Sounds/Bottle.aiff"

# Play notification sound (non-blocking)
play_sound() {
  if [ "$SOUND_ENABLED" = "true" ] && [ -f "$SOUND_FILE" ]; then
    afplay "$SOUND_FILE" &
  fi
}

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
# Validate PRD file exists
if [ ! -f "$PRD_FILE" ]; then
  echo "❌ ERROR: PRD file not found: $PRD_FILE" >&2
  echo "" >&2
  echo "Available PRD files:" >&2
  ls -la *.md 2>/dev/null | grep -i prd | head -5 >&2 || echo "  (none found)" >&2
  echo "" >&2
  echo "Usage: $0 [loops] [child_loops] --prd=<filename>" >&2
  exit 1
fi

# Validate PRD file is not empty
if [ ! -s "$PRD_FILE" ]; then
  echo "❌ ERROR: PRD file is empty: $PRD_FILE" >&2
  exit 1
fi

# Ensure progress.txt exists (create if missing)
if [ ! -f "progress.txt" ]; then
  echo "📝 Creating progress.txt (was missing)"
  echo "# Progress Log - $(date '+%Y-%m-%d %H:%M:%S')" > progress.txt
fi

# Validate CLI selection
if [ "$CLI_BIN" != "claude" ] && [ "$CLI_BIN" != "codex" ] && [ "$CLI_BIN" != "cursor-agent" ]; then
  echo "❌ ERROR: --cli must be 'claude', 'codex', or 'cursor-agent' (got: $CLI_BIN)" >&2
  exit 1
fi

# Validate selected CLI is available
if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "❌ ERROR: '$CLI_BIN' CLI not found in PATH" >&2
  if [ "$CLI_BIN" = "claude" ]; then
    echo "Install: https://docs.anthropic.com/claude/docs/claude-cli" >&2
  fi
  exit 1
fi

echo "✅ Validation passed: PRD=$PRD_FILE ($(wc -c < "$PRD_FILE" | tr -d ' ') bytes)"

#═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
#═══════════════════════════════════════════════════════════════════════════════
# Detect if script is being sourced vs executed
# This script should be EXECUTED, not sourced. If sourced, use return instead of exit.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Script is being executed (normal case - recommended)
  SCRIPT_EXIT="exit"
else
  # Script is being sourced - not recommended but handle gracefully
  SCRIPT_EXIT="return"
  echo "⚠️  WARNING: Script is being sourced. For best results, execute with: ./plan-an-go-forever.sh" >&2
fi

iteration=0
start_time=$(date +%s)
STOP_REQUESTED=false
PIPELINE_THREAD_TS=""  # Single thread for entire pipeline run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Load Slack helpers from repo root (or scripts/ if placed there) only when Slack is enabled
if [ "$USE_SLACK" = "true" ]; then
  if [ -f "$REPO_ROOT/plan-an-go-slack-update.sh" ]; then
    source "$REPO_ROOT/plan-an-go-slack-update.sh"
  elif [ -f "$SCRIPT_DIR/plan-an-go-slack-update.sh" ]; then
    source "$SCRIPT_DIR/plan-an-go-slack-update.sh"
  fi
fi

# Unified Slack posting (threaded when enabled, plain otherwise); no-op when --no-slack
post_slack_message() {
  [ "$USE_SLACK" != "true" ] && return 0
  local message="$1"
  local thread_ts="${2:-}"

  if [ "$SLACK_USE_THREADS" = "true" ] && [ -n "$thread_ts" ] && command -v post_to_slack_thread &> /dev/null; then
    post_to_slack_thread "$message" "$thread_ts" 2>/dev/null || true
  elif command -v post_to_slack &> /dev/null; then
    post_to_slack "$message" 2>/dev/null || true
  fi
}

# Graceful shutdown handler (Ctrl+C)
handle_stop_request() {
  if [ "$STOP_REQUESTED" = "false" ]; then
    STOP_REQUESTED=true
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⏸️  STOP REQUESTED - Will exit after current iteration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Post to Slack (threaded or plain based on setting)
    post_slack_message "⏸️ *Stop requested* — will exit after current iteration completes" "$PIPELINE_THREAD_TS"
  fi
}

# Trap Ctrl+C (SIGINT) for graceful shutdown
trap handle_stop_request SIGINT

# Helper function to format seconds as HH:MM:SS
format_duration() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Programmatic task count verification
# Returns: "COMPLETE" if all tasks done, or "X incomplete" count
verify_prd_completion() {
  local prd_file="${1:-PRD.md}"
  
  if [ ! -f "$prd_file" ]; then
    echo "PRD_NOT_FOUND"
    return 1
  fi
  
  # Count all incomplete task checkboxes: template "- [ ] **" or bracket "[  ] -" (two spaces = unchecked)
  local template_incomplete
  template_incomplete=$(grep -c '^\- \[ \] \*\*' "$prd_file" 2>/dev/null) || template_incomplete=0
  local bracket_incomplete
  bracket_incomplete=$(grep -c '^\[  \] -' "$prd_file" 2>/dev/null) || bracket_incomplete=0
  local all_incomplete=$((template_incomplete + bracket_incomplete))
  
  # Count CHECK.X tasks (validation gate tasks - template style only)
  local check_tasks
  check_tasks=$(grep -c '^\- \[ \] \*\*CHECK\.' "$prd_file" 2>/dev/null) || check_tasks=0
  
  # Count incomplete tasks marked with [UI] or [FUNCTIONAL] tags (treated as incomplete per PRD legend)
  local ui_incomplete
  ui_incomplete=$(grep -c '^\- \[x\] \[UI\]' "$prd_file" 2>/dev/null) || ui_incomplete=0
  
  local func_incomplete
  func_incomplete=$(grep -c '^\- \[x\] \[FUNCTIONAL\]' "$prd_file" 2>/dev/null) || func_incomplete=0
  
  # Implementation tasks = all incomplete minus CHECK tasks
  local impl_incomplete=$((all_incomplete - check_tasks))
  
  # Total truly incomplete = implementation tasks + [UI]/[FUNCTIONAL] tagged tasks
  local total_incomplete=$((impl_incomplete + ui_incomplete + func_incomplete))
  
  if [ "$total_incomplete" -eq 0 ]; then
    echo "COMPLETE"
  else
    echo "$total_incomplete incomplete (impl: $impl_incomplete, check: $check_tasks, ui: $ui_incomplete, func: $func_incomplete)"
  fi
}

# Strip [IN_PROGRESS] from all lines in the plan/PRD file (portable sed)
strip_in_progress_from_file() {
  local f="${1:-$PRD_FILE}"
  [ ! -f "$f" ] && return 0
  sed 's/ \[IN_PROGRESS\]//g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

# Remove [IN_PROGRESS] only from lines that are marked complete ([x])
# Call after implementer runs so the file is clean once a task is marked done.
strip_in_progress_from_completed_lines() {
  local f="${1:-$PRD_FILE}"
  [ ! -f "$f" ] && return 0
  sed '/\[x\]/s/ \[IN_PROGRESS\]//g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
}

# When implementer runs in a read-only sandbox it cannot edit the PRD; it reports success
# but COMMIT/FILES show "read-only" or "N/A". Parse its output and mark that task [x] so
# the pipeline can move to the next task.
mark_task_complete_from_implementer_output() {
  local impl_output="$1"
  local f="${2:-$PRD_FILE}"
  [ ! -f "$f" ] && return 0
  [ ! -f "$impl_output" ] && return 0
  # Only act when agent reported it couldn't write (read-only)
  if ! grep -q "read-only\|N/A.*read-only\|None (read-only" "$impl_output" 2>/dev/null; then
    return 0
  fi
  # Extract task id from FEATURE: M1:3 or FEATURE: M2:1
  local task_id
  task_id=$(sed -n '/------START: IMPLEMENTER------/,/------END: IMPLEMENTER------/p' "$impl_output" 2>/dev/null | grep -oE 'FEATURE:[[:space:]]*[M0-9]+:[0-9]+' | head -1 | sed 's/FEATURE:[[:space:]]*//')
  [ -z "$task_id" ] && return 0
  # Mark the unchecked line that contains this task id (e.g. "[ ] - M1:3- ...") as [x]
  if grep -q "^\[ \] - ${task_id}-" "$f" 2>/dev/null; then
    sed "s/^\[ \] - ${task_id}-/[x] - ${task_id}-/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  elif grep -q "^\[  \] - ${task_id}-" "$f" 2>/dev/null; then
    sed "s/^\[  \] - ${task_id}-/[x] - ${task_id}-/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}

# Write [IN_PROGRESS] to the first incomplete task line so the file reflects "working on this task".
# Call before running the implementer; extract-incomplete-tasks.sh will include it in the prompt.
mark_first_incomplete_in_progress() {
  local f="${1:-$PRD_FILE}"
  [ ! -f "$f" ] && return 0
  local first_ln
  first_ln=$(grep -n -m1 -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$f" 2>/dev/null | cut -d: -f1)
  if [ -n "$first_ln" ]; then
    sed "${first_ln}s/$/ [IN_PROGRESS]/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}

# Bouncing bar spinner
spinner_bounce() {
  local pid=$1
  local msg=$2
  local frames=("[=    ]" "[ =   ]" "[  =  ]" "[   = ]" "[    =]" "[   = ]" "[  =  ]" "[ =   ]")
  local i=0
  local start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    local elapsed=$(($(date +%s) - start))
    printf "\r%s %s (%ds)" "${frames[i++ % 8]}" "$msg" "$elapsed" >&2
    sleep 0.15
  done
  local final_elapsed=$(($(date +%s) - start))
  printf "\r✓ %s (%ds)              \n" "$msg" "$final_elapsed" >&2
}

# Extract full formatted report from agent output for Slack
# Posts the complete report (like history.log) but truncated at char limit
extract_summary() {
  local output="$1"
  local agent="$2"
  local max_chars="${3:-8800}"  # Slack limit is ~4000, leave room for code block wrapper
  
  # Extract content between START and END markers (full report)
  local section
  section=$(echo "$output" | sed -n "/------START: $agent------/,/------END: $agent------/p")
  
  # If section is empty, try to get any meaningful content
  if [ -z "$section" ]; then
    section=$(echo "$output" | head -50)
  fi
  
  # Truncate at character limit, but try to end at a line boundary
  if [ ${#section} -gt $max_chars ]; then
    # Cut at max_chars, then find last newline to avoid mid-line cut
    local truncated="${section:0:$max_chars}"
    local last_newline=$(echo "$truncated" | grep -bo $'\n' | tail -1 | cut -d: -f1)
    
    if [ -n "$last_newline" ] && [ "$last_newline" -gt $((max_chars - 200)) ]; then
      section="${truncated:0:$last_newline}"
    else
      section="$truncated"
    fi
    section="$section
..._(truncated)_"
  fi
  
  echo "$section"
}

#═══════════════════════════════════════════════════════════════════════════════
# HEADER
#═══════════════════════════════════════════════════════════════════════════════
initial_prd_status=$(verify_prd_completion "$PRD_FILE")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$SKIP_VALIDATION" = "true" ]; then
  echo "🤖 Plan-an-go Pipeline - Implementer Only Mode"
else
  echo "🤖 Plan-an-go Pipeline - 2-Agent System"
fi
echo "   (7-step: Plan → Think → Research → Distill → Sub-tasks → Work → Validate; sub-agents when available)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Parent loops: $MAX_ITERATIONS"
echo "🔄 Child loops (per agent): $MAX_CHILD_LOOPS"
echo "📝 Log file: $LOG_FILE"
echo "📢 Slack: $([ "$USE_SLACK" = "true" ] && echo "enabled (threads: $SLACK_USE_THREADS)" || echo "disabled")"
echo "🔍 Validation: $([ "$SKIP_VALIDATION" = "true" ] && echo "DISABLED" || echo "enabled")"
echo "📺 Streaming: $([ "$STREAM_OUTPUT" = "true" ] && echo "ENABLED (gray bg)" || echo "disabled")"
echo "🤖 CLI: $CLI_BIN"
[ -n "$TAIL_LOG" ] && echo "📄 Tail log: $TAIL_LOG (tail -f $TAIL_LOG in another terminal to watch current iteration)"
echo "📋 PRD File: $PRD_FILE"
echo "📋 PRD Status: $initial_prd_status"
echo "⏰ Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
if [ "$SKIP_VALIDATION" = "true" ]; then
  echo "Pipeline: IMPLEMENTER → LOG → SLACK (no validation)"
else
  echo "Pipeline: IMPLEMENTER → VALIDATOR → LOG → SLACK (validated, repeatable)"
fi
echo "⏸️  Press Ctrl+C to stop gracefully after current iteration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create single parent thread for entire pipeline (if Slack enabled and threading enabled)
if [ "$USE_SLACK" = "true" ]; then
  if [ "$SLACK_USE_THREADS" = "true" ] && command -v post_to_slack_get_ts &> /dev/null; then
    PIPELINE_THREAD_TS=$(post_to_slack_get_ts "🚀 *Plan-an-go Pipeline Started* | Parent: $MAX_ITERATIONS | Child: $MAX_CHILD_LOOPS" 2>/dev/null || echo "")
    if [ -n "$PIPELINE_THREAD_TS" ]; then
      echo "🧵 Slack pipeline thread created: $PIPELINE_THREAD_TS"
    fi
  else
    post_slack_message "🚀 *Plan-an-go Pipeline Started* | Parent: $MAX_ITERATIONS | Child: $MAX_CHILD_LOOPS"
  fi
fi

#═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
#═══════════════════════════════════════════════════════════════════════════════
# Debug: Verify loop will actually run
if [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
  echo "⚠️  ERROR: iteration ($iteration) >= MAX_ITERATIONS ($MAX_ITERATIONS) - loop will not run!" >&2
  echo "⚠️  This should not happen. Check variable initialization." >&2
  $SCRIPT_EXIT 1
fi

while [ $iteration -lt $MAX_ITERATIONS ]; do
  iteration=$((iteration + 1))
  iter_start=$(date +%s)
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔄 ITERATION $iteration of $MAX_ITERATIONS"
  echo "⏰ $(date '+%Y-%m-%d %H:%M:%S')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Create temp files
  impl_output=$(mktemp)
  val_output=$(mktemp)
  if [ -n "$TAIL_LOG" ]; then
    echo "═══════════════════════════════════════════════════════════════════════════════" > "$TAIL_LOG"
    echo "ITERATION $iteration of $MAX_ITERATIONS — $(date '+%Y-%m-%d %H:%M:%S')" >> "$TAIL_LOG"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$TAIL_LOG"
    echo "" >> "$TAIL_LOG"
    echo "--- IMPLEMENTER ---" >> "$TAIL_LOG"
    echo "" >> "$TAIL_LOG"
  fi
  #─────────────────────────────────────────────────────────────────────────────
  # SLACK: Post iteration start to thread
  #─────────────────────────────────────────────────────────────────────────────
  post_slack_message "🔄 *Iteration $iteration of $MAX_ITERATIONS*" "$PIPELINE_THREAD_TS"
  
  #─────────────────────────────────────────────────────────────────────────────
  # PLAN FILE: Write [IN_PROGRESS] on the first incomplete task before implementer runs
  #─────────────────────────────────────────────────────────────────────────────
  strip_in_progress_from_file "$PRD_FILE"
  mark_first_incomplete_in_progress "$PRD_FILE"
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 1: IMPLEMENTER AGENT
  #─────────────────────────────────────────────────────────────────────────────
  echo ""
  echo "📝 STAGE 1: Running Implementer Agent..."
  first_task=$(grep -m1 -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$PRD_FILE" 2>/dev/null)
  if [ -n "$first_task" ]; then
    task_display="$first_task"
    task_display="${task_display#- [ ] }"
    task_display="${task_display#\[  \] - }"
    task_display="${task_display#\[ \] - }"
    echo "   Task: $task_display"
  fi
  echo ""
  if [ "$STREAM_OUTPUT" = "true" ]; then
    # Streaming mode: show output in real-time
    echo "📺 Streaming implementer output..."
    if [ -n "$TAIL_LOG" ]; then
      PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true ./plan-an-go.sh 2>&1 | tee "$impl_output" >> "$TAIL_LOG"
    else
      PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true ./plan-an-go.sh 2>&1 | tee "$impl_output"
    fi
    impl_exit=${PIPESTATUS[0]}
  else
    # Batch mode: use spinner while capturing
    if [ -n "$TAIL_LOG" ]; then
      impl_exit_file=$(mktemp)
      { PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS ./plan-an-go.sh 2>&1; echo $? > "$impl_exit_file"; } | tee "$impl_output" >> "$TAIL_LOG" &
      impl_pid=$!
      spinner_bounce $impl_pid "Implementer working"
      wait $impl_pid
      impl_exit=$(cat "$impl_exit_file")
      rm -f "$impl_exit_file"
    else
      PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS ./plan-an-go.sh > "$impl_output" 2>&1 &
      impl_pid=$!
      spinner_bounce $impl_pid "Implementer working"
      wait $impl_pid
      impl_exit=$?
    fi
  fi
  
  impl_result=$(cat "$impl_output")
  
  # Check for critical failures that should stop the pipeline
  IMPL_FAILED=false
  IMPL_FAIL_REASON=""
  
  # Check for credit exhaustion
  if echo "$impl_result" | grep -q "Credit balance is too low"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="CREDITS_EXHAUSTED"
  # Check for empty output (timeout or silent failure)
  elif [ -z "$impl_result" ] || [ ${#impl_result} -lt 50 ]; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="EMPTY_OUTPUT"
  # Check for ERROR in structured output
  elif echo "$impl_result" | grep -q "^ERROR:"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="AGENT_ERROR"
  # Check for VERDICT: FAILED
  elif echo "$impl_result" | grep -q "VERDICT: FAILED"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="VALIDATION_FAILED"
  # Check for non-zero exit code
  elif [ $impl_exit -ne 0 ]; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="EXIT_CODE_$impl_exit"
  fi
  
  if [ "$IMPL_FAILED" = "true" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ IMPLEMENTER FAILED - $IMPL_FAIL_REASON"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Output received (${#impl_result} chars):"
    echo "$impl_result" | head -20
    echo ""
    
    # Log failure
    echo "" >> "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "ITERATION $iteration - FAILED ($IMPL_FAIL_REASON)" >> "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "$impl_result" >> "$LOG_FILE"
    
    # Post to Slack
    post_slack_message "❌ *IMPLEMENTER FAILED* - $IMPL_FAIL_REASON at iteration $iteration" "$PIPELINE_THREAD_TS"
    
    rm -f "$impl_output" "$val_output"
    $SCRIPT_EXIT 1
  fi
  
  # If implementer ran read-only and reported success, mark that task [x] so pipeline advances
  mark_task_complete_from_implementer_output "$impl_output" "$PRD_FILE"
  # Remove [IN_PROGRESS] from any task line the implementer marked complete ([x])
  strip_in_progress_from_completed_lines "$PRD_FILE"
  
  # Log to file
  echo "" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "ITERATION $iteration - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "$impl_result" >> "$LOG_FILE"
  
  # Display (only if not streaming, since tee already showed it)
  if [ "$STREAM_OUTPUT" != "true" ]; then
    echo ""
    echo "$impl_result"
  fi
  
  # Slack: Post implementer update to thread (wrapped in code block)
  impl_summary=$(extract_summary "$impl_result" "IMPLEMENTER")
  # Remove all backticks to prevent breaking the Slack code block
  impl_summary=$(printf '%s' "$impl_summary" | tr -d '`')
  impl_slack_msg=$(printf '📝 *IMPLEMENTER*\n```\n%s\n```' "$impl_summary")
  post_slack_message "$impl_slack_msg" "$PIPELINE_THREAD_TS"
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 2: VALIDATOR AGENT (skipped with --no-validate)
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$SKIP_VALIDATION" = "true" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⏭️  STAGE 2: Skipping Validator (--no-validate)"
    val_result=""
    val_exit=0
  else
    if [ -n "$TAIL_LOG" ]; then
      echo "" >> "$TAIL_LOG"
      echo "--- VALIDATOR ---" >> "$TAIL_LOG"
      echo "" >> "$TAIL_LOG"
    fi
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 STAGE 2: Running Validator Agent..."
    
    if [ "$STREAM_OUTPUT" = "true" ]; then
      # Streaming mode: show output in real-time
      echo "📺 Streaming validator output..."
      if [ -n "$TAIL_LOG" ]; then
        PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true ./plan-an-go-validate.sh "$impl_output" 2>&1 | tee "$val_output" >> "$TAIL_LOG"
      else
        PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true ./plan-an-go-validate.sh "$impl_output" 2>&1 | tee "$val_output"
      fi
      val_exit=${PIPESTATUS[0]}
    else
      # Batch mode: use spinner while capturing
      if [ -n "$TAIL_LOG" ]; then
        val_exit_file=$(mktemp)
        { PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS ./plan-an-go-validate.sh "$impl_output" 2>&1; echo $? > "$val_exit_file"; } | tee "$val_output" >> "$TAIL_LOG" &
        val_pid=$!
        spinner_bounce $val_pid "Validator auditing"
        wait $val_pid
        val_exit=$(cat "$val_exit_file")
        rm -f "$val_exit_file"
      else
        PRD_FILE=$PRD_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS ./plan-an-go-validate.sh "$impl_output" > "$val_output" 2>&1 &
        val_pid=$!
        spinner_bounce $val_pid "Validator auditing"
        wait $val_pid
        val_exit=$?
      fi
    fi
    
    val_result=$(cat "$val_output")
    
    # Check for credit exhaustion
    if echo "$val_result" | grep -q "Credit balance is too low"; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "❌ CREDITS EXHAUSTED - Stopping pipeline"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      # Post to Slack
      post_slack_message "❌ *CREDITS EXHAUSTED* - Pipeline stopped at iteration $iteration" "$PIPELINE_THREAD_TS"
      
      rm -f "$impl_output" "$val_output"
      $SCRIPT_EXIT 1
    fi
    
    # Log to file
    echo "" >> "$LOG_FILE"
    echo "$val_result" >> "$LOG_FILE"
    
    # Display (only if not streaming, since tee already showed it)
    if [ "$STREAM_OUTPUT" != "true" ]; then
      echo ""
      echo "$val_result"
    fi
    
    # Slack: Post validator update to thread (wrapped in code block)
    val_summary=$(extract_summary "$val_result" "VALIDATOR")
    # Remove all backticks to prevent breaking the Slack code block
    val_summary=$(printf '%s' "$val_summary" | tr -d '`')
    val_slack_msg=$(printf '🔍 *VALIDATOR*\n```\n%s\n```' "$val_summary")
    post_slack_message "$val_slack_msg" "$PIPELINE_THREAD_TS"
    
    # Check for errors
    if [ $val_exit -ne 0 ]; then
      echo ""
      echo "❌ Validator agent failed with exit code $val_exit"
      
      post_slack_message "❌ Validator failed (exit: $val_exit)" "$PIPELINE_THREAD_TS"
      
      rm -f "$impl_output" "$val_output"
      sleep 5
      continue
    fi
  fi
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 3: PROCESS RESULTS
  #─────────────────────────────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  iter_end=$(date +%s)
  iter_duration=$((iter_end - iter_start))
  total_elapsed=$((iter_end - start_time))
  
  # Extract metrics from validator output (POSIX-compatible, works on macOS and Linux)
  if [ "$SKIP_VALIDATION" = "true" ]; then
    # Default values when validation is skipped
    confidence="N/A"
    verdict="SKIPPED"
    status="CONTINUE"
    mode="NO_VALIDATION"
  else
    # Try TASK_VALIDATION format first, then CHECK_PHASE format
    confidence=$(echo "$val_result" | sed -n 's/.*CONFIDENCE SCORE: \([0-9]*\).*/\1/p' | head -1)
    [ -z "$confidence" ] && confidence=$(echo "$val_result" | sed -n 's/.*MILESTONE CONFIDENCE SCORE: \([0-9]*\).*/\1/p' | head -1)
    confidence="${confidence:-?}"
    
    verdict=$(echo "$val_result" | sed -n 's/.*VERDICT: \([A-Z_]*\).*/\1/p' | head -1)
    [ -z "$verdict" ] && verdict=$(echo "$val_result" | sed -n 's/.*GATE DECISION: \([A-Z_]*\).*/\1/p' | head -1)
    verdict="${verdict:-UNKNOWN}"
    
    status=$(echo "$val_result" | sed -n 's/.*<status>\([A-Z_]*\)<\/status>.*/\1/p' | head -1)
    status="${status:-CONTINUE}"
    
    mode=$(echo "$val_result" | sed -n 's/.*MODE: \([A-Z_]*\).*/\1/p' | head -1)
    mode="${mode:-TASK_VALIDATION}"
  fi
  
  # Calculate ETA
  avg_per_iter=$((total_elapsed / iteration))
  remaining=$((MAX_ITERATIONS - iteration))
  eta=$((avg_per_iter * remaining))
  
  # Get current PRD status for display
  current_prd_status=$(verify_prd_completion "$PRD_FILE")
  
  echo "📊 ITERATION $iteration SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔧 Mode: $mode"
  echo "⏱️  Duration: $(format_duration $iter_duration)"
  echo "📈 Confidence: $confidence/10"
  echo "✅ Verdict: $verdict"
  echo "📌 Status: $status"
  echo "📋 PRD: $current_prd_status"
  echo "⏳ Total elapsed: $(format_duration $total_elapsed)"
  echo "📊 Avg/iteration: ${avg_per_iter}s"
  echo "⏳ ETA remaining: $(format_duration $eta)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Play completion sound
  play_sound
  
  #─────────────────────────────────────────────────────────────────────────────
  # SLACK: Final summary (thread reply or standalone)
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$USE_SLACK" = "true" ]; then
    summary_msg="📊 *Summary*
• Mode: $mode
• Confidence: $confidence/10
• Verdict: $verdict
• Status: $status
• Duration: $(format_duration $iter_duration)
• ETA: $(format_duration $eta)"

    if [ "$SLACK_USE_THREADS" = "true" ] && [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
      # Post summary as thread reply
      post_to_slack_thread "$summary_msg" "$PIPELINE_THREAD_TS" 2>/dev/null || true
    elif [ "$SLACK_USE_THREADS" != "true" ] && command -v post_to_slack &> /dev/null; then
      # Single combined message (non-threaded mode)
      # First iteration: include pipeline started header
      if [ "$iteration" -eq 1 ]; then
        header="🚀 *Plan-an-go Pipeline Started* | Parent: $MAX_ITERATIONS | Child: $MAX_CHILD_LOOPS | 📊 *Iteration $iteration Summary*"
      else
        header="📊 *Iteration $iteration Summary*"
      fi

      impl_code=$(extract_summary "$impl_result" "IMPLEMENTER")
      val_code=$(extract_summary "$val_result" "VALIDATOR")
      # Remove all backticks to prevent breaking Slack code blocks
      impl_code=$(printf '%s' "$impl_code" | tr -d '`')
      val_code=$(printf '%s' "$val_code" | tr -d '`')

      combined_msg=$(printf '%s\n\n%s\n\n*Implementer:*\n```\n%s\n```\n\n*Validator:*\n```\n%s\n```' \
        "$header" "$summary_msg" "$impl_code" "$val_code")

      # Truncate if too long
      if [ ${#combined_msg} -gt 3500 ]; then
        combined_msg="${combined_msg:0:3500}..._(truncated)_"
      fi

      post_to_slack "$combined_msg" 2>/dev/null || true
    fi
  fi
  
  # Clean up temp files
  rm -f "$impl_output" "$val_output"
  
  # Remove [IN_PROGRESS] from any task line that was marked complete ([x])
  strip_in_progress_from_completed_lines "$PRD_FILE"
  
  #─────────────────────────────────────────────────────────────────────────────
  # POST-ITERATION: PLAN STATUS CHECK
  #─────────────────────────────────────────────────────────────────────────────
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 PLAN STATUS (after iteration $iteration)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  PLAN_CHECK_SCRIPT="$SCRIPT_DIR/plan-an-go-plan-check.sh"
  if [ "$PRD_FILE" = "PRD.md" ]; then
    PLAN_CHECK_FILE="$SCRIPT_DIR/PLAN.md"
  else
    PLAN_CHECK_FILE="$PRD_FILE"
  fi
  if [ -f "$PLAN_CHECK_SCRIPT" ]; then
    if [ -x "$PLAN_CHECK_SCRIPT" ]; then
      "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE"
    else
      echo "⚠️  Plan check script is not executable: $PLAN_CHECK_SCRIPT"
      echo "    Running via bash (you can also: chmod +x \"$PLAN_CHECK_SCRIPT\")"
      bash "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE"
    fi
    plan_check_exit=$?
    if [ $plan_check_exit -ne 0 ]; then
      echo "⚠️  Plan check reported issues (exit $plan_check_exit). Pipeline will continue."
    fi
  else
    echo "⚠️  Plan check script not found: $PLAN_CHECK_SCRIPT"
  fi

  #─────────────────────────────────────────────────────────────────────────────
  # CHECK COMPLETION STATUS (with programmatic verification)
  #─────────────────────────────────────────────────────────────────────────────
  
  # Handle CHECK phase statuses
  if [ "$status" = "CHECK_PHASE_COMPLETE" ]; then
    echo ""
    echo "✅ CHECK phase complete - Ready to proceed to next milestone"
    status="CONTINUE"  # Continue to next milestone's implementation tasks
  elif [ "$status" = "CHECK_PHASE_NEEDS_WORK" ]; then
    echo ""
    echo "⚠️  CHECK phase incomplete - Corrective actions required"
    status="CONTINUE"  # Continue with corrective tasks
  elif [ "$status" = "MILESTONE_NEEDS_COMPLETION" ]; then
    echo ""
    echo "⚠️  CHECK phase passed but milestone tasks remain - Continue implementation"
    status="CONTINUE"
  fi
  
  # Verify LLM's completion claim against actual PRD file state
  if [ "$status" = "ALL_TASKS_COMPLETE" ]; then
    prd_status=$(verify_prd_completion "$PRD_FILE")
    
    if [ "$prd_status" != "COMPLETE" ]; then
      echo ""
      echo "⚠️  LLM CLAIMED ALL_TASKS_COMPLETE BUT PRD.md SHOWS: $prd_status"
      echo "⚠️  Overriding status to CONTINUE - false positive detected"
      echo ""
      status="CONTINUE"
      
      # Log the false positive
      echo "FALSE POSITIVE DETECTED: LLM claimed ALL_TASKS_COMPLETE but PRD.md shows $prd_status" >> "$LOG_FILE"

      # Notify Slack about the false positive
      if [ "$USE_SLACK" = "true" ]; then
        if [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
          post_to_slack_thread "⚠️ *False Positive Detected*
LLM claimed ALL_TASKS_COMPLETE but PRD.md shows: $prd_status
Continuing pipeline..." "$PIPELINE_THREAD_TS" 2>/dev/null || true
        elif command -v post_to_slack &> /dev/null; then
          post_to_slack "⚠️ *False Positive Detected*
LLM claimed ALL_TASKS_COMPLETE but PRD.md shows: $prd_status
Continuing pipeline..." 2>/dev/null || true
        fi
      fi
    fi
  fi
  
  if [ "$status" = "ALL_TASKS_COMPLETE" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 ALL TASKS COMPLETE!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Total iterations: $iteration"
    echo "⏱️  Total time: $(format_duration $total_elapsed)"
    echo "⏰ Finished: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    strip_in_progress_from_file "$PRD_FILE"
    
    complete_msg="🎉 *ALL TASKS COMPLETE!*

Total iterations: $iteration
Total time: $(format_duration $total_elapsed)
Finished: $(date '+%Y-%m-%d %H:%M:%S')"

    if [ "$USE_SLACK" = "true" ]; then
      if [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
        post_to_slack_thread "$complete_msg" "$PIPELINE_THREAD_TS" 2>/dev/null || true
      elif command -v post_to_slack &> /dev/null; then
        post_to_slack "$complete_msg" 2>/dev/null || true
      fi
    fi

    $SCRIPT_EXIT 0
  fi
  
  #─────────────────────────────────────────────────────────────────────────────
  # CHECK FOR GRACEFUL SHUTDOWN REQUEST
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$STOP_REQUESTED" = "true" ]; then
    total_elapsed=$(($(date +%s) - start_time))
    
    strip_in_progress_from_file "$PRD_FILE"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🛑 MANUALLY STOPPED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Completed iterations: $iteration"
    echo "⏱️  Total time: $(format_duration $total_elapsed)"
    echo "⏰ Stopped: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Post final message to thread if available, otherwise standalone
    stop_msg="🛑 *Manually Stopped*

Completed iterations: $iteration of $MAX_ITERATIONS
Total time: $(format_duration $total_elapsed)
Stopped: $(date '+%Y-%m-%d %H:%M:%S')"

    if [ "$USE_SLACK" = "true" ]; then
      if [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
        post_to_slack_thread "$stop_msg" "$PIPELINE_THREAD_TS" 2>/dev/null || true
      elif command -v post_to_slack &> /dev/null; then
        post_to_slack "$stop_msg" 2>/dev/null || true
      fi
    fi

    $SCRIPT_EXIT 0
  fi
  
  # Brief pause between iterations
  sleep 2
done

#═══════════════════════════════════════════════════════════════════════════════
# MAX ITERATIONS REACHED
#═══════════════════════════════════════════════════════════════════════════════
total_elapsed=$(($(date +%s) - start_time))

strip_in_progress_from_file "$PRD_FILE"

# Safety check: If script completed too quickly, something is wrong
if [ "$total_elapsed" -lt 5 ] && [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
  echo ""
  echo "⚠️  WARNING: Script completed $MAX_ITERATIONS iterations in $(format_duration $total_elapsed)" >&2
  echo "⚠️  WARNING: This is suspiciously fast. Possible issues:" >&2
  echo "⚠️  WARNING:   1. Script may have exited early due to an error" >&2
  echo "⚠️  WARNING:   2. Loop condition may be incorrect" >&2
  echo "⚠️  WARNING:   3. Child scripts may be failing immediately" >&2
  echo "⚠️  WARNING: Check logs and ensure scripts are executable." >&2
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏸️  MAX ITERATIONS REACHED ($MAX_ITERATIONS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏱️  Total time: $(format_duration $total_elapsed)"
echo "📝 Full log: $LOG_FILE"
echo "⏰ Finished: $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

max_iter_msg="⏸️ *Max iterations reached* ($MAX_ITERATIONS)

Total time: $(format_duration $total_elapsed)
Run again to continue."

if [ "$USE_SLACK" = "true" ]; then
  if [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
    post_to_slack_thread "$max_iter_msg" "$PIPELINE_THREAD_TS" 2>/dev/null || true
  elif command -v post_to_slack &> /dev/null; then
    post_to_slack "$max_iter_msg" 2>/dev/null || true
  fi
fi
