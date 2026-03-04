#!/bin/bash
# plan-an-go-forever.sh — ORCHESTRATOR: Runs Implementer → Validator pipeline
# Usage: ./plan-an-go-forever.sh [parent_loops] [child_loops] [--no-validate] [--no-threads] [--stream] [--no-slack|--slack-enable] [--workspace DIR] [--plan FILE] [--cli claude|codex|cursor-agent] [--cli-flags "<flags>"]
#
# Implementer uses a 7-step workflow: Plan → Think → Research → Distill → Sub-tasks →
# Work (with sub-agents if available) → Validate & quantify before check-off.
# When run from Cursor, the implementer can delegate to sub-agents (e.g. explore,
# generalPurpose, test-runner, verifier) to accomplish work faster. All work is
# validated and repeatable.
#
# Slack: Disabled by default. Use --slack-enable (or USE_SLACK=true) to enable; requires
# PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN or PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN. If enabled
# but tokens are unset or a post fails, we warn and continue (no exit).
# Optional: run ./plan-an-go-file-watch.sh in another terminal to watch repo changes while the pipeline runs.
#
# Arguments:
#   parent_loops   - Number of orchestrator iterations (default: 100)
#   child_loops    - Max LLM API calls per agent invocation (default: 50)
#   --no-validate  - Skip validation step (implementer only mode)
#   --no-threads   - Disable Slack threads (post messages directly to channel)
#   --stream       - Stream LLM output in real-time with gray background
#   --no-slack     - Disable Slack (default)
#   --slack-enable - Enable Slack (requires Slack tokens in .env)
#   --tail[=FILE]  - Write implementer + validator output to FILE (default: ./tmp/pipeline-tail.log)
#                    so you can "tail -f FILE" in another terminal to see current iteration.
#                    File is overwritten at the start of each iteration.
#   --workspace    - Run from this directory (default: repo root containing scripts/cli)
#   --plan         - Plan file path (default: PLAN.md; resolved relative to workspace)
#   --cli          - LLM CLI to use: claude, codex, or cursor-agent (default: claude)
#   --cli-flags    - Extra flags passed through to the CLI (quoted string)
#   --concurrency N - Run N implementer agents in parallel; each picks one of the first N
#                     incomplete tasks. Tasks are marked [IN_PROGRESS]:[AGENT_01] ... [AGENT_N].
#                     Default: 1 (single agent).
#   --clean-after   - After exit (complete, max iterations, or stop), remove workspace contents.
#                     Requires --force; only runs when workspace is a subdir of the script repo.
#   --force         - Required with --clean-after to confirm cleanup.
#   --verbose       - Full iteration summaries, plan-check output; otherwise one-line progress.
#                     Or set PLAN_AN_GO_VERBOSE=true.
#   --quiet         - Only header, errors, and final completion/stop; no per-iteration progress.
#                     Or set PLAN_AN_GO_QUIET=true.
#
# Examples:
#   ./plan-an-go-forever.sh                    # 100 parent loops, 50 child loops, with validation
#   ./plan-an-go-forever.sh 100 50             # 100 parent loops, 50 child loops, with validation
#   ./plan-an-go-forever.sh 100 50 --no-validate  # Skip validation, implementer only
#   ./plan-an-go-forever.sh --no-threads         # Post updates directly to channel
#   ./plan-an-go-forever.sh --slack-enable       # Enable Slack (tokens required)
#   ./plan-an-go-forever.sh --no-validate      # Default loops, skip validation
#   ./plan-an-go-forever.sh --tail              # Write iteration output to ./tmp/pipeline-tail.log; tail -f to watch
#   ./plan-an-go-forever.sh --tail=my.log       # Use my.log for tail output
#   ./plan-an-go-forever.sh --cli codex         # Use codex CLI instead of claude
#   ./plan-an-go-forever.sh --cli cursor-agent  # Use cursor-agent CLI (auto model)
#   ./plan-an-go-forever.sh --workspace /path/to/project  # Run pipeline in another repo
#   ./plan-an-go-forever.sh --verbose                    # Full summaries and plan-check output
#   ./plan-an-go-forever.sh --quiet                      # Minimal output (header + errors + final)
#
# Pipeline per iteration:
#   1. AGENT 1 (Implementer): Plan/Think/Research/Distill → Sub-tasks → Work (sub-agents if available) → Validate → ONE task (up to child_loops calls)
#   2. AGENT 2 (Validator): Audits, quantifies completion, checks repeatability, runs tests, updates plan (up to child_loops calls)
#      (skipped with --no-validate)
#   3. ORCHESTRATOR: Logs results, posts to Slack, decides next action

set -e
set -o pipefail

#═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
#═══════════════════════════════════════════════════════════════════════════════
# Parse arguments - check for --no-validate, --no-threads, --plan, --workspace, --stream, --tail, --no-slack/--slack-enable, --cli
SKIP_VALIDATION=false
STREAM_OUTPUT=false
PLAN_FILE="PLAN.md"
WORKSPACE=""
TAIL_LOG=""
USE_SLACK="${USE_SLACK:-false}"
SLACK_USE_THREADS="${SLACK_USE_THREADS:-true}"
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
CONCURRENCY=1
CLEAN_AFTER=false
FORCE=false
VERBOSE="${PLAN_AN_GO_VERBOSE:-false}"
QUIET="${PLAN_AN_GO_QUIET:-false}"
POSITIONAL_ARGS=()
PREV_ARG=""
for arg in "$@"; do
  case $arg in
    --verbose)
      VERBOSE=true
      ;;
    --quiet)
      QUIET=true
      ;;
    --concurrency=*)
      CONCURRENCY="${arg#*=}"
      ;;
    --clean-after)
      CLEAN_AFTER=true
      ;;
    --force)
      FORCE=true
      ;;
    --no-validate)
      SKIP_VALIDATION=true
      ;;
    --no-threads|--no-thread|--simple-slack)
      SLACK_USE_THREADS=false
      ;;
    --no-slack)
      USE_SLACK=false
      ;;
    --slack-enable)
      USE_SLACK=true
      ;;
    --stream)
      STREAM_OUTPUT=true
      ;;
    --tail)
      TAIL_LOG="__default__"
      ;;
    --tail=*)
      TAIL_LOG="${arg#*=}"
      ;;
    --workspace=*)
      WORKSPACE="${arg#*=}"
      ;;
    --plan=*)
      PLAN_FILE="${arg#*=}"
      ;;
    --cli=*)
      CLI_BIN="${arg#*=}"
      ;;
    --cli-flags=*)
      CLI_FLAGS="${arg#*=}"
      ;;
    --workspace)
      # Handle --workspace <dir> format (next arg is the path)
      ;;
    --plan)
      # Handle --plan <file> format (next arg is the file)
      ;;
    --cli)
      # Handle --cli <value> format (next arg is the CLI)
      ;;
    --cli-flags)
      # Handle --cli-flags <value> format (next arg is the flags)
      ;;
    --concurrency)
      # Handle --concurrency N (next arg is the value)
      ;;
    *)
      if [ "${PREV_ARG}" = "--workspace" ]; then
        WORKSPACE="$arg"
      elif [ "${PREV_ARG}" = "--plan" ]; then
        PLAN_FILE="$arg"
      elif [ "${PREV_ARG}" = "--cli" ]; then
        CLI_BIN="$arg"
      elif [ "${PREV_ARG}" = "--cli-flags" ]; then
        CLI_FLAGS="$arg"
      elif [ "${PREV_ARG}" = "--concurrency" ]; then
        CONCURRENCY="$arg"
      else
        POSITIONAL_ARGS+=("$arg")
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

# Clean workspace contents after exit; only when --clean-after and --force, and workspace is a subdir of script repo
clean_workspace_after_exit() {
  [ "$CLEAN_AFTER" != "true" ] && return 0
  [ "$FORCE" != "true" ] && return 0
  SCRIPT_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  # Only clean when REPO_ROOT is a subdirectory of script repo (not repo root itself)
  case "$REPO_ROOT" in
    "$SCRIPT_REPO_ROOT") return 0 ;;  # do not clean repo root
    "$SCRIPT_REPO_ROOT"/*) ;;
    *) return 0 ;;
  esac
  echo ""
  echo "--- Cleaning workspace (--clean-after --force) ---"
  rm -rf "${REPO_ROOT:?}"/*
  echo "  Done."
}

# Resolve CLI flags: use PLAN_AN_GO_CLI_FLAGS if set, else per-CLI vars
if [ -z "$CLI_FLAGS" ]; then
  case "$CLI_BIN" in
    claude) CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    codex)  CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    *)      CLI_FLAGS="" ;;
  esac
fi

# Normalize concurrency to a positive integer
CONCURRENCY=$(printf '%d' "$CONCURRENCY" 2>/dev/null || echo 1)
[ "$CONCURRENCY" -lt 1 ] && CONCURRENCY=1

# Export for child scripts
export STREAM_OUTPUT
export USE_SLACK
export PLAN_AN_GO_CLI="$CLI_BIN"
export PLAN_AN_GO_CLI_FLAGS="$CLI_FLAGS"

MAX_ITERATIONS=${POSITIONAL_ARGS[0]:-100}
MAX_CHILD_LOOPS=${POSITIONAL_ARGS[1]:-50}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# From scripts/cli, repo root is two levels up; or use --workspace
if [ -n "$WORKSPACE" ]; then
  if [ ! -d "$WORKSPACE" ]; then
    echo "❌ ERROR: Workspace directory not found: $WORKSPACE" >&2
    exit 1
  fi
  REPO_ROOT="$(cd "$WORKSPACE" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
IMPL_SCRIPT="$SCRIPT_DIR/plan-an-go.sh"
VAL_SCRIPT="$SCRIPT_DIR/plan-an-go-validate.sh"
# Run from workspace/repo root so PLAN_FILE, LOG_FILE, and implementer/validator paths resolve
cd "$REPO_ROOT" || exit 1

# All pipeline logs and temp files under ./tmp by default.
# When PLAN_AN_GO_TMP is set (e.g. in .env), use a workspace-unique subdir so progress/history/tail
# do not collide across different workspaces.
TMP_BASE="${PLAN_AN_GO_TMP:-./tmp}"
if [ -n "${PLAN_AN_GO_TMP:-}" ]; then
  WORKSPACE_ID=$(echo -n "$REPO_ROOT" | openssl dgst -sha256 2>/dev/null | awk '{print $2}' | cut -c1-8)
  [ -z "$WORKSPACE_ID" ] && WORKSPACE_ID="default"
  TMP_DIR="$TMP_BASE/$WORKSPACE_ID"
else
  TMP_DIR="$TMP_BASE"
fi
mkdir -p "$TMP_DIR"
LOG_FILE="$TMP_DIR/history.log"
[ "$TAIL_LOG" = "__default__" ] && TAIL_LOG="$TMP_DIR/pipeline-tail.log"
PROGRESS_FILE="$TMP_DIR/progress.txt"

# Display paths: relative when under REPO_ROOT for cleaner output
DISPLAY_PLAN="$PLAN_FILE"
DISPLAY_LOG="$LOG_FILE"
case "$PLAN_FILE" in "$REPO_ROOT"/*) DISPLAY_PLAN="./${PLAN_FILE#$REPO_ROOT/}"; esac
case "$LOG_FILE" in "$REPO_ROOT"/*) DISPLAY_LOG="./${LOG_FILE#$REPO_ROOT/}"; esac

# If Slack enabled, require at least one token; otherwise disable and warn (do not exit)
if [ "$USE_SLACK" = "true" ]; then
  [ -f "$REPO_ROOT/.env" ] && set -a && source "$REPO_ROOT/.env" 2>/dev/null && set +a
  if [ -z "${PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN:-}" ] && [ -z "${SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${SLACK_APP_ACCESS_TOKEN:-}" ]; then
    echo "⚠️  Slack enabled but no Slack tokens set (PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN or PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN); disabling Slack." >&2
    USE_SLACK=false
  fi
fi

# Sound notification: plays when iteration completes
SOUND_ENABLED=true
SOUND_FILE="/System/Library/Sounds/Bottle.aiff"

# Play notification sound (non-blocking)
play_sound() {
  if [ "$SOUND_ENABLED" = "true" ] && [ -f "$SOUND_FILE" ]; then
    afplay "$SOUND_FILE" &
  fi
}

# Spoken summary after each completed task (optional). Call with: impl_output val_output iteration confidence verdict
# No-op if TTS_AFTER_TASK is not true or OPENAI_API_KEY is unset.
play_tts_after_task() {
  local impl_out="$1"
  local val_out="$2"
  local iter="${3:-0}"
  local conf="${4:-N/A}"
  local ver="${5:-PASSED}"
  [ "${TTS_AFTER_TASK:-false}" != "true" ] && return 0
  [ -z "${OPENAI_API_KEY:-}" ] && return 0
  local tts_script="$SCRIPT_DIR/plan-an-go-tts-summary.sh"
  [ ! -f "$tts_script" ] && return 0
  IMPL_OUTPUT="$impl_out" VAL_OUTPUT="$val_out" PLAN_FILE="$PLAN_FILE" \
    ITERATION="$iter" CONFIDENCE="$conf" VERDICT="$ver" \
    REPO_ROOT="$REPO_ROOT" PLAN_AN_GO_TMP="${TMP_DIR:-./tmp}" \
    TTS_SUMMARY_PROMPT_FILE="${TTS_SUMMARY_PROMPT_FILE:-}" TTS_SUMMARY_MODEL="${TTS_SUMMARY_MODEL:-}" \
    TTS_TONE="${TTS_TONE:-}" TTS_VOICE="${TTS_VOICE:-}" TTS_MODEL="${TTS_MODEL:-}" TTS_SPEED="${TTS_SPEED:-}" \
    OPENAI_API_KEY="$OPENAI_API_KEY" \
    bash "$tts_script" 2>/dev/null || true
}

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
# Resolve plan file to absolute path for all checks and child scripts
if [[ "$PLAN_FILE" != /* ]]; then
  PLAN_FILE="$REPO_ROOT/$PLAN_FILE"
fi

# Validate plan file exists
if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ ERROR: Plan file not found: $PLAN_FILE" >&2
  echo "" >&2
  echo "Available plan files:" >&2
  (cd "$REPO_ROOT" && ls -la *.md 2>/dev/null | head -5) >&2 || echo "  (none found)" >&2
  echo "" >&2
  echo "Usage: $0 [loops] [child_loops] [--workspace DIR] [--plan=<filename>] [--clean-after] [--force]" >&2
  exit 1
fi

# Validate plan file is not empty
if [ ! -s "$PLAN_FILE" ]; then
  echo "❌ ERROR: Plan file is empty: $PLAN_FILE" >&2
  exit 1
fi

# Ensure progress log exists under tmp
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Progress Log - $(date '+%Y-%m-%d %H:%M:%S')" > "$PROGRESS_FILE"
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

# Load Slack helpers from repo root (or scripts/ if placed there) only when Slack is enabled
if [ "$USE_SLACK" = "true" ]; then
  if [ -f "$REPO_ROOT/plan-an-go-slack-update.sh" ]; then
    source "$REPO_ROOT/plan-an-go-slack-update.sh"
  elif [ -f "$SCRIPT_DIR/plan-an-go-slack-update.sh" ]; then
    source "$SCRIPT_DIR/plan-an-go-slack-update.sh"
  fi
fi

# Unified Slack posting (threaded when enabled, plain otherwise); no-op when Slack disabled. On failure, warn and continue.
post_slack_message() {
  [ "$USE_SLACK" != "true" ] && return 0
  local message="$1"
  local thread_ts="${2:-}"
  local err

  if [ "$SLACK_USE_THREADS" = "true" ] && [ -n "$thread_ts" ] && command -v post_to_slack_thread &> /dev/null; then
    err=$(post_to_slack_thread "$message" "$thread_ts" 2>&1) || { echo "⚠️  Slack post failed: $err" >&2; return 0; }
  elif command -v post_to_slack &> /dev/null; then
    err=$(post_to_slack "$message" 2>&1) || { echo "⚠️  Slack post failed: $err" >&2; return 0; }
  fi
}

# Graceful shutdown handler (Ctrl+C)
handle_stop_request() {
  if [ "$STOP_REQUESTED" = "false" ]; then
    STOP_REQUESTED=true
    echo ""
    echo "--- Stop requested (exiting after current iteration) ---"
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

# Short duration for one-line summary: 1m23s or 0h12m34s
format_duration_short() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  if [ "$hours" -gt 0 ]; then
    printf "%dh%02dm%02ds" "$hours" "$minutes" "$seconds"
  elif [ "$minutes" -gt 0 ]; then
    printf "%dm%02ds" "$minutes" "$seconds"
  else
    printf "%ds" "$seconds"
  fi
}

# Strip checkbox and [IN_PROGRESS]:[AGENT_NN] for display; output task ID and description only
format_task_line_for_display() {
  local line="$1"
  line="${line#- [ ] }"
  line="${line#\[  \] - }"
  line="${line#\[ \] - }"
  echo "$line" | sed -e 's/ \[IN_PROGRESS\]:\[AGENT_[0-9]*\]$//' -e 's/ \[IN_PROGRESS\]$//'
}

# Programmatic task count verification
# Returns: "COMPLETE" if all tasks done, or "X incomplete" count
verify_plan_completion() {
  local plan_file="${1:-PLAN.md}"
  
  if [ ! -f "$plan_file" ]; then
    echo "PLAN_NOT_FOUND"
    return 1
  fi
  
  # Count all incomplete task checkboxes: template "- [ ] **" or bracket "[  ] -" (two spaces = unchecked)
  local template_incomplete
  template_incomplete=$(grep -c '^\- \[ \] \*\*' "$plan_file" 2>/dev/null) || template_incomplete=0
  local bracket_incomplete
  bracket_incomplete=$(grep -c '^\[  \] -' "$plan_file" 2>/dev/null) || bracket_incomplete=0
  local all_incomplete=$((template_incomplete + bracket_incomplete))
  
  # Count CHECK.X tasks (validation gate tasks - template style only)
  local check_tasks
  check_tasks=$(grep -c '^\- \[ \] \*\*CHECK\.' "$plan_file" 2>/dev/null) || check_tasks=0
  
  # Count incomplete tasks marked with [UI] or [FUNCTIONAL] tags (treated as incomplete per plan legend)
  local ui_incomplete
  ui_incomplete=$(grep -c '^\- \[x\] \[UI\]' "$plan_file" 2>/dev/null) || ui_incomplete=0
  
  local func_incomplete
  func_incomplete=$(grep -c '^\- \[x\] \[FUNCTIONAL\]' "$plan_file" 2>/dev/null) || func_incomplete=0
  
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

# Ensure plan file ends with a newline (keeps markdown valid)
ensure_plan_trailing_newline() {
  local f="$1"
  [ ! -f "$f" ] && return 0
  case "$(tail -c1 "$f" 2>/dev/null)" in
    '') return 0 ;;
    $'\n') return 0 ;;
    *) echo >> "$f" ;;
  esac
}

# Strip [IN_PROGRESS] and [IN_PROGRESS]:[AGENT_NN] from all lines (portable sed)
strip_in_progress_from_file() {
  local f="${1:-$PLAN_FILE}"
  [ ! -f "$f" ] && return 0
  sed -e 's/ \[IN_PROGRESS\]:\[AGENT_[0-9]*\]//g' -e 's/ \[IN_PROGRESS\]//g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  ensure_plan_trailing_newline "$f"
}

# On lines marked complete ([x]): convert [IN_PROGRESS]:[AGENT_NN] to [AGENT_NN] (keep agent);
# remove bare [IN_PROGRESS] (no agent).
strip_in_progress_from_completed_lines() {
  local f="${1:-$PLAN_FILE}"
  [ ! -f "$f" ] && return 0
  sed -e '/\[x\]/s/ \[IN_PROGRESS\]:\(\[AGENT_[0-9]*\]\)/ \1/g' -e '/\[x\]/s/ \[IN_PROGRESS\]//g' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  ensure_plan_trailing_newline "$f"
}

# When implementer runs in a read-only sandbox it cannot edit the plan file; it reports success
# but COMMIT/FILES show "read-only" or "N/A". Parse its output and mark that task [x] so
# the pipeline can move to the next task.
mark_task_complete_from_implementer_output() {
  local impl_output="$1"
  local f="${2:-$PLAN_FILE}"
  [ ! -f "$f" ] && return 0
  [ ! -f "$impl_output" ] && return 0
  # Only act when agent reported it couldn't write (read-only)
  if ! grep -q "read-only\|N/A.*read-only\|None (read-only" "$impl_output" 2>/dev/null; then
    return 0
  fi
  # Extract task id from FEATURE: M1:3 or FEATURE: M2:1
  local task_id
  task_id=$(sed -n '/------START: IMPLEMENTER------/,/------END: IMPLEMENTER------/p' "$impl_output" 2>/dev/null | grep -oE 'FEATURE:[[:space:]]*[M0-9]+:[0-9]+' | head -1 | sed 's/FEATURE:[[:space:]]*//') || task_id=""
  [ -z "$task_id" ] && return 0
  # Mark the unchecked line that contains this task id (e.g. "[ ] - M1:3- ...") as [x]
  if grep -q "^\[ \] - ${task_id}-" "$f" 2>/dev/null; then
    sed "s/^\[ \] - ${task_id}-/[x] - ${task_id}-/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    ensure_plan_trailing_newline "$f"
    return 0
  fi
  if grep -q "^\[  \] - ${task_id}-" "$f" 2>/dev/null; then
    sed "s/^\[  \] - ${task_id}-/[x] - ${task_id}-/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
  ensure_plan_trailing_newline "$f"
}

# Write [IN_PROGRESS] to the first incomplete task line (concurrency=1).
mark_first_incomplete_in_progress() {
  local f="${1:-$PLAN_FILE}"
  [ ! -f "$f" ] && return 0
  local first_ln
  first_ln=$(grep -n -m1 -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$f" 2>/dev/null | cut -d: -f1) || first_ln=""
  if [ -n "$first_ln" ]; then
    sed "${first_ln}s/$/ [IN_PROGRESS]/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    ensure_plan_trailing_newline "$f"
  fi
}

# Write [IN_PROGRESS]:[AGENT_01] ... [IN_PROGRESS]:[AGENT_N] to the first N incomplete task lines.
# Call when CONCURRENCY > 1; each agent gets one assigned task.
mark_next_n_incomplete_in_progress() {
  local f="${1:-$PLAN_FILE}"
  local n="${2:-1}"
  [ ! -f "$f" ] && return 0
  [ "$n" -lt 1 ] && return 0
  local line_nums
  line_nums=$(grep -n -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$f" 2>/dev/null | head -n "$n" | cut -d: -f1) || line_nums=""
  [ -z "$line_nums" ] && return 0
  local idx=1
  local sed_expr=""
  for ln in $line_nums; do
    local agent_id
    agent_id=$(printf 'AGENT_%02d' "$idx")
    sed_expr="${sed_expr}${sed_expr:+;}${ln}s/\$/ [IN_PROGRESS]:[${agent_id}]/"
    idx=$(( idx + 1 ))
  done
  sed "$sed_expr" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  ensure_plan_trailing_newline "$f"
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
    local last_newline
    last_newline=$(echo "$truncated" | grep -bo $'\n' | tail -1 | cut -d: -f1) || last_newline=""

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
initial_plan_status=$(verify_plan_completion "$PLAN_FILE")
PLAN_BYTES=$(wc -c < "$PLAN_FILE" 2>/dev/null | tr -d ' ')

if [ "$SKIP_VALIDATION" = "true" ]; then
  echo "Plan-an-go · Implementer only (no validation)"
else
  echo "Plan-an-go · 2-Agent (Implementer → Validator)"
fi
echo "  Plan: $DISPLAY_PLAN (${PLAN_BYTES} B)  ·  Log: $DISPLAY_LOG  ·  CLI: $CLI_BIN"
echo "  Loops: $MAX_ITERATIONS parent, $MAX_CHILD_LOOPS child  ·  Started $(date '+%Y-%m-%d %H:%M:%S')  ·  Plan: $initial_plan_status"
slack_label="off"
[ "$USE_SLACK" = "true" ] && slack_label="on" && [ "$SLACK_USE_THREADS" = "true" ] && slack_label="on (threads)"
echo "  Slack: $slack_label  ·  Validation: $([ "$SKIP_VALIDATION" = "true" ] && echo "off" || echo "on")  ·  Stream: $([ "$STREAM_OUTPUT" = "true" ] && echo "on" || echo "off")"
[ -n "$TAIL_LOG" ] && echo "  Tail: $TAIL_LOG (tail -f to watch)"
echo "  Ctrl+C to stop after current iteration"
echo ""

# Create single parent thread for entire pipeline (if Slack enabled and threading enabled)
if [ "$USE_SLACK" = "true" ]; then
  if [ "$SLACK_USE_THREADS" = "true" ] && command -v post_to_slack_get_ts &> /dev/null; then
    PIPELINE_THREAD_TS=$(post_to_slack_get_ts "🚀 *Plan-an-go Pipeline Started* | Parent: $MAX_ITERATIONS | Child: $MAX_CHILD_LOOPS" 2>/dev/null) || true
    if [ -n "$PIPELINE_THREAD_TS" ]; then
      echo "🧵 Slack pipeline thread created: $PIPELINE_THREAD_TS"
    else
      echo "⚠️  Slack pipeline thread creation failed; posts will be in channel (no thread)." >&2
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
  
  [ "$QUIET" != "true" ] && echo ""
  [ "$QUIET" != "true" ] && echo "--- Iteration $iteration/$MAX_ITERATIONS ($(date '+%Y-%m-%d %H:%M:%S')) ---"

  # Create temp files under tmp/
  impl_output=$(mktemp "$TMP_DIR/forever-impl.XXXXXX")
  val_output=$(mktemp "$TMP_DIR/forever-val.XXXXXX")
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
  # PLAN FILE: Mark incomplete task(s) for implementer(s)
  #─────────────────────────────────────────────────────────────────────────────
  strip_in_progress_from_file "$PLAN_FILE"
  if [ "$CONCURRENCY" -eq 1 ]; then
    mark_first_incomplete_in_progress "$PLAN_FILE"
  else
    mark_next_n_incomplete_in_progress "$PLAN_FILE" "$CONCURRENCY"
  fi
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 1: IMPLEMENTER AGENT(S)
  #─────────────────────────────────────────────────────────────────────────────
  task_parts=()
  while IFS= read -r task_line; do
    [ -z "$task_line" ] && continue
    task_parts+=("$(format_task_line_for_display "$task_line")")
  done < <(grep -E '^(\- \[ \] \*\*|\[  \] -|\[ \] -)' "$PLAN_FILE" 2>/dev/null | head -n "$CONCURRENCY")
  if [ "$QUIET" != "true" ]; then
    if [ "$CONCURRENCY" -eq 1 ]; then
      [ ${#task_parts[@]} -gt 0 ] && echo "Implementer: ${task_parts[0]}"
    else
      impl_task_list=$(IFS=' · '; echo "${task_parts[*]}")
      [ -n "$impl_task_list" ] && echo "Implementer ($CONCURRENCY concurrent): $impl_task_list"
    fi
    echo ""
  fi
  
  if [ "$CONCURRENCY" -eq 1 ]; then
    if [ "$STREAM_OUTPUT" = "true" ]; then
      [ "$QUIET" != "true" ] && echo "Streaming implementer..."
      if [ -n "$TAIL_LOG" ]; then
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$IMPL_SCRIPT" 2>&1 | tee "$impl_output" >> "$TAIL_LOG"
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$IMPL_SCRIPT" 2>&1 | tee "$impl_output"
      fi
      impl_exit=${PIPESTATUS[0]}
    else
      if [ -n "$TAIL_LOG" ]; then
        impl_exit_file=$(mktemp "$TMP_DIR/forever-exit.XXXXXX")
        { PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$IMPL_SCRIPT" 2>&1; echo $? > "$impl_exit_file"; } | tee "$impl_output" >> "$TAIL_LOG" &
        impl_pid=$!
        if [ "$QUIET" = "true" ]; then wait $impl_pid; else spinner_bounce $impl_pid "Implementer working"; wait $impl_pid; fi
        impl_exit=$(cat "$impl_exit_file")
        rm -f "$impl_exit_file"
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$IMPL_SCRIPT" > "$impl_output" 2>&1 &
        impl_pid=$!
        if [ "$QUIET" = "true" ]; then wait $impl_pid; else spinner_bounce $impl_pid "Implementer working"; wait $impl_pid; fi
        impl_exit=$?
      fi
    fi
  else
    # CONCURRENCY > 1: run N implementers in parallel (batch only)
    impl_pids=()
    impl_outputs=()
    for i in $(seq 1 "$CONCURRENCY"); do
      agent_id=$(printf 'AGENT_%02d' "$i")
      out_f=$(mktemp "$TMP_DIR/forever-agent.XXXXXX")
      impl_outputs+=("$out_f")
      PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS PLAN_AN_GO_AGENT_ID="$agent_id" "$IMPL_SCRIPT" > "$out_f" 2>&1 &
      impl_pids+=($!)
    done
    impl_exit=0
    for p in "${impl_pids[@]}"; do
      wait "$p" || impl_exit=$?
    done
    for f in "${impl_outputs[@]}"; do
      [ -f "$f" ] && mark_task_complete_from_implementer_output "$f" "$PLAN_FILE"
    done
    cat "${impl_outputs[@]}" > "$impl_output" 2>/dev/null || true
    rm -f "${impl_outputs[@]}"
  fi
  
  impl_result=$(cat "$impl_output")
  
  # Check for critical failures that should stop the pipeline
  IMPL_FAILED=false
  IMPL_FAIL_REASON=""
  
  if echo "$impl_result" | grep -q "Credit balance is too low"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="CREDITS_EXHAUSTED"
  elif [ -z "$impl_result" ] || [ ${#impl_result} -lt 50 ]; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="EMPTY_OUTPUT"
  elif echo "$impl_result" | grep -q "^ERROR:"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="AGENT_ERROR"
  elif echo "$impl_result" | grep -q "VERDICT: FAILED"; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="VALIDATION_FAILED"
  elif [ $impl_exit -ne 0 ]; then
    IMPL_FAILED=true
    IMPL_FAIL_REASON="EXIT_CODE_$impl_exit"
  fi
  
  if [ "$IMPL_FAILED" = "true" ]; then
    echo ""
    echo "Implementer failed ($IMPL_FAIL_REASON). First 10 lines:"
    echo "$impl_result" | head -10 | sed 's/^/  /'
    echo "Full output: $DISPLAY_LOG"
    echo ""
    echo "" >> "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "ITERATION $iteration - FAILED ($IMPL_FAIL_REASON)" >> "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
    echo "$impl_result" >> "$LOG_FILE"
    post_slack_message "❌ *IMPLEMENTER FAILED* - $IMPL_FAIL_REASON at iteration $iteration" "$PIPELINE_THREAD_TS"
    rm -f "$impl_output" "$val_output"
    $SCRIPT_EXIT 1
  fi
  
  if [ "$CONCURRENCY" -eq 1 ]; then
    mark_task_complete_from_implementer_output "$impl_output" "$PLAN_FILE"
  fi
  strip_in_progress_from_completed_lines "$PLAN_FILE"
  
  echo "" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "ITERATION $iteration - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  echo "═══════════════════════════════════════════════════════════════════════════════" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "$impl_result" >> "$LOG_FILE"
  
  if [ "$STREAM_OUTPUT" != "true" ] && [ "$QUIET" != "true" ]; then
    echo ""
    echo "$impl_result"
  fi
  
  impl_summary=$(extract_summary "$impl_result" "IMPLEMENTER")
  impl_summary=$(printf '%s' "$impl_summary" | tr -d '`')
  impl_slack_msg=$(printf '📝 *IMPLEMENTER*\n```\n%s\n```' "$impl_summary")
  post_slack_message "$impl_slack_msg" "$PIPELINE_THREAD_TS"
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 2: VALIDATOR AGENT (skipped with --no-validate)
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$SKIP_VALIDATION" = "true" ]; then
    [ "$VERBOSE" = "true" ] && echo "Validator: skipped (--no-validate)"
    val_result=""
    val_exit=0
  else
    if [ -n "$TAIL_LOG" ]; then
      echo "" >> "$TAIL_LOG"
      echo "--- VALIDATOR ---" >> "$TAIL_LOG"
      echo "" >> "$TAIL_LOG"
    fi
    [ "$VERBOSE" = "true" ] && echo "Validator: running..."
    if [ "$STREAM_OUTPUT" = "true" ]; then
      [ "$QUIET" != "true" ] && echo "Streaming validator..."
      if [ -n "$TAIL_LOG" ]; then
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$VAL_SCRIPT" "$impl_output" 2>&1 | tee "$val_output" >> "$TAIL_LOG"
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$VAL_SCRIPT" "$impl_output" 2>&1 | tee "$val_output"
      fi
      val_exit=${PIPESTATUS[0]}
    else
      # Batch mode: use spinner while capturing
      if [ -n "$TAIL_LOG" ]; then
        val_exit_file=$(mktemp "$TMP_DIR/forever-val-exit.XXXXXX")
        { PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$VAL_SCRIPT" "$impl_output" 2>&1; echo $? > "$val_exit_file"; } | tee "$val_output" >> "$TAIL_LOG" &
        val_pid=$!
        if [ "$QUIET" = "true" ]; then wait $val_pid; else spinner_bounce $val_pid "Validator auditing"; wait $val_pid; fi
        val_exit=$(cat "$val_exit_file")
        rm -f "$val_exit_file"
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$VAL_SCRIPT" "$impl_output" > "$val_output" 2>&1 &
        val_pid=$!
        if [ "$QUIET" = "true" ]; then wait $val_pid; else spinner_bounce $val_pid "Validator auditing"; wait $val_pid; fi
        val_exit=$?
      fi
    fi
    
    val_result=$(cat "$val_output")
    
    # Check for credit exhaustion
    if echo "$val_result" | grep -q "Credit balance is too low"; then
      echo ""
      echo "--- Credits exhausted - stopping ---"
      echo "  Log: $DISPLAY_LOG"
      # Post to Slack
      post_slack_message "❌ *CREDITS EXHAUSTED* - Pipeline stopped at iteration $iteration" "$PIPELINE_THREAD_TS"
      
      rm -f "$impl_output" "$val_output"
      $SCRIPT_EXIT 1
    fi
    
    # Log to file
    echo "" >> "$LOG_FILE"
    echo "$val_result" >> "$LOG_FILE"
    
    # Display (only if not streaming and not quiet, since tee already showed it when streaming)
    if [ "$STREAM_OUTPUT" != "true" ] && [ "$QUIET" != "true" ]; then
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
      echo "Validator failed (exit $val_exit). Continuing in 5s..."
      post_slack_message "❌ Validator failed (exit: $val_exit)" "$PIPELINE_THREAD_TS"
      
      rm -f "$impl_output" "$val_output"
      sleep 5
      continue
    fi
  fi
  
  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 3: PROCESS RESULTS
  #─────────────────────────────────────────────────────────────────────────────
  iter_end=$(date +%s)
  iter_duration=$((iter_end - iter_start))
  total_elapsed=$((iter_end - start_time))

  # Extract metrics from validator output (POSIX-compatible, works on macOS and Linux)
  if [ "$SKIP_VALIDATION" = "true" ]; then
    confidence="N/A"
    verdict="SKIPPED"
    status="CONTINUE"
    mode="NO_VALIDATION"
  else
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

  avg_per_iter=$((total_elapsed / iteration))
  remaining=$((MAX_ITERATIONS - iteration))
  eta=$((avg_per_iter * remaining))
  current_plan_status=$(verify_plan_completion "$PLAN_FILE")

  if [ "$VERBOSE" = "true" ]; then
    echo ""
    echo "--- Iteration $iteration summary ---"
    echo "  Mode: $mode  ·  Duration: $(format_duration $iter_duration)  ·  Confidence: $confidence/10  ·  Verdict: $verdict"
    echo "  Status: $status  ·  Plan: $current_plan_status"
    echo "  Elapsed: $(format_duration $total_elapsed)  ·  Avg/iter: ${avg_per_iter}s  ·  ETA: $(format_duration $eta)"
  elif [ "$QUIET" != "true" ]; then
    # One line: iteration, duration, plan, verdict (when validation on), ETA
    if [ "$SKIP_VALIDATION" = "true" ]; then
      echo "Iteration $iteration · $(format_duration_short $iter_duration) · Plan: $current_plan_status · ETA: $(format_duration_short $eta)"
    else
      echo "Iteration $iteration · $(format_duration_short $iter_duration) · Plan: $current_plan_status · Verdict: $verdict · ETA: $(format_duration_short $eta)"
    fi
  fi
  
  # Play completion sound
  play_sound
  play_tts_after_task "$impl_output" "$val_output" "$iteration" "$confidence" "$verdict"

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
  strip_in_progress_from_completed_lines "$PLAN_FILE"
  
  #─────────────────────────────────────────────────────────────────────────────
  # POST-ITERATION: PLAN STATUS CHECK
  #─────────────────────────────────────────────────────────────────────────────
  PLAN_CHECK_SCRIPT="$SCRIPT_DIR/plan-an-go-plan-check.sh"
  PLAN_CHECK_FILE="$PLAN_FILE"
  if [ -f "$PLAN_CHECK_SCRIPT" ]; then
    if [ "$VERBOSE" = "true" ]; then
      echo ""
      if [ -x "$PLAN_CHECK_SCRIPT" ]; then
        "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE"
      else
        bash "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE"
      fi
      plan_check_exit=$?
      [ $plan_check_exit -ne 0 ] && echo "Plan check reported issues (exit $plan_check_exit). Pipeline continues."
    else
      # One-line status already shown in iteration summary; run check silently for exit code
      if [ -x "$PLAN_CHECK_SCRIPT" ]; then
        "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE" >/dev/null 2>&1 || true
      else
        bash "$PLAN_CHECK_SCRIPT" "$PLAN_CHECK_FILE" >/dev/null 2>&1 || true
      fi
    fi
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
  
  # Verify LLM's completion claim against actual plan file state
  if [ "$status" = "ALL_TASKS_COMPLETE" ]; then
    plan_status=$(verify_plan_completion "$PLAN_FILE")
    
    if [ "$plan_status" != "COMPLETE" ]; then
      echo ""
      echo "⚠️  LLM CLAIMED ALL_TASKS_COMPLETE BUT PLAN SHOWS: $plan_status"
      echo "⚠️  Overriding status to CONTINUE - false positive detected"
      echo ""
      status="CONTINUE"
      
      # Log the false positive
      echo "FALSE POSITIVE DETECTED: LLM claimed ALL_TASKS_COMPLETE but plan shows $plan_status" >> "$LOG_FILE"

      # Notify Slack about the false positive
      if [ "$USE_SLACK" = "true" ]; then
        if [ -n "$PIPELINE_THREAD_TS" ] && command -v post_to_slack_thread &> /dev/null; then
          post_to_slack_thread "⚠️ *False Positive Detected*
LLM claimed ALL_TASKS_COMPLETE but plan shows: $plan_status
Continuing pipeline..." "$PIPELINE_THREAD_TS" 2>/dev/null || true
        elif command -v post_to_slack &> /dev/null; then
          post_to_slack "⚠️ *False Positive Detected*
LLM claimed ALL_TASKS_COMPLETE but plan shows: $plan_status
Continuing pipeline..." 2>/dev/null || true
        fi
      fi
    fi
  fi
  
  if [ "$status" = "ALL_TASKS_COMPLETE" ]; then
    echo ""
    echo "--- All tasks complete ---"
    echo "  Iterations: $iteration  ·  Time: $(format_duration_short $total_elapsed)  ·  Finished $(date '+%Y-%m-%d %H:%M:%S')"
    
    strip_in_progress_from_file "$PLAN_FILE"
    
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

    clean_workspace_after_exit
    $SCRIPT_EXIT 0
  fi
  
  #─────────────────────────────────────────────────────────────────────────────
  # CHECK FOR GRACEFUL SHUTDOWN REQUEST
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$STOP_REQUESTED" = "true" ]; then
    total_elapsed=$(($(date +%s) - start_time))
    strip_in_progress_from_file "$PLAN_FILE"
    echo ""
    echo "--- Stopped (Ctrl+C) ---"
    echo "  Iterations: $iteration/$MAX_ITERATIONS  ·  Time: $(format_duration_short $total_elapsed)  ·  Stopped $(date '+%Y-%m-%d %H:%M:%S')"
    
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

    clean_workspace_after_exit
    $SCRIPT_EXIT 0
  fi

  # Brief pause between iterations
  sleep 2
done

#═══════════════════════════════════════════════════════════════════════════════
# MAX ITERATIONS REACHED
#═══════════════════════════════════════════════════════════════════════════════
total_elapsed=$(($(date +%s) - start_time))

strip_in_progress_from_file "$PLAN_FILE"

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
echo "--- Max iterations reached ($MAX_ITERATIONS) ---"
echo "  Time: $(format_duration_short $total_elapsed)  ·  Log: $DISPLAY_LOG  ·  Finished $(date '+%Y-%m-%d %H:%M:%S')"

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

clean_workspace_after_exit
