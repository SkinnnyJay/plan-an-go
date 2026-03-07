#!/bin/bash
# plan-an-go-forever.sh — ORCHESTRATOR: Runs Implementer → Validator pipeline
# Usage: ./plan-an-go-forever.sh [parent_loops] [child_loops] [--no-validate] [--wait-for-all] [--stream] [--no-slack|--slack-enable] [--workspace DIR] [--plan FILE] [--cli claude|cline|copilot|codex|cursor-agent|droid|gemini|goose|kiro|opencode] [--concurrency N] [--cli-flags "<flags>"]
#
# Implementer uses a 7-step workflow: Plan → Think → Research → Distill → Sub-tasks →
# Work (with sub-agents if available) → Validate & quantify before check-off.
# When run from Cursor, the implementer can delegate to sub-agents (e.g. explore,
# generalPurpose, test-runner, verifier) to accomplish work faster. All work is
# validated and repeatable.
#
# Slack: Disabled by default. Use --slack-enable (or PLAN_AN_GO_USE_SLACK=true) to enable; requires
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
#   --cli          - LLM CLI to use: claude, cline, copilot, codex, cursor-agent, droid, gemini, goose, kiro, or opencode (default: claude)
#   --cli-flags    - Extra flags passed through to the CLI (quoted string)
#   --concurrency N - Run N implementer agents in parallel; each picks one of the first N
#                     incomplete tasks. Tasks are marked [IN_PROGRESS]:[AGENT_01] ... [AGENT_N].
#                     Default: 1 (single agent).
#   --wait-for-all  - When N>1: wait for all N agents to finish before next round (default: false).
#                     Default (pool): when an agent finishes it immediately takes the next task.
#   --clean-after   - After exit (complete, max iterations, or stop), remove workspace contents.
#                     Requires --force; only runs when workspace is a subdir of the script repo.
#   --force         - Required with --clean-after to confirm cleanup.
#   --strict        - Require plan to be <work>-compliant (see README). Non-compliant plans exit 1.
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
STREAM_OUTPUT="${PLAN_AN_GO_STREAM_OUTPUT:-${STREAM_OUTPUT:-false}}"
PLAN_FILE="PLAN.md"
WORKSPACE=""
TAIL_LOG=""
USE_SLACK="${PLAN_AN_GO_USE_SLACK:-${USE_SLACK:-false}}"
SLACK_USE_THREADS="${PLAN_AN_GO_SLACK_USE_THREADS:-${SLACK_USE_THREADS:-true}}"
STREAM_SET_BY_ARG=false
SLACK_SET_BY_ARG=false
THREADS_SET_BY_ARG=false
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
CLI_FLAGS="${PLAN_AN_GO_CLI_FLAGS:-}"
CONCURRENCY=1
CLEAN_AFTER=false
FORCE=false
VERBOSE="${PLAN_AN_GO_VERBOSE:-false}"
QUIET="${PLAN_AN_GO_QUIET:-false}"
OUTPUT_TYPE="${PLAN_AN_GO_OUTPUT_TYPE:-stdout}"
USE_COLOR="${PLAN_AN_GO_USE_COLOR:-true}"
HIGHLIGHT_AGENTS="${PLAN_AN_GO_HIGHLIGHT_AGENTS:-false}"
STRICT_WORK="${PLAN_AN_GO_STRICT:-false}"
# When false (default): finished agents immediately take the next task (pool). When true: wait for all N to finish before next round.
WAIT_FOR_ALL="${PLAN_AN_GO_WAIT_FOR_ALL:-false}"
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
    --no-color)
      USE_COLOR=false
      ;;
    --highlight-agents)
      HIGHLIGHT_AGENTS=true
      ;;
    --output-type=*)
      OUTPUT_TYPE="${arg#*=}"
      ;;
    --output-type)
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
    --strict)
      STRICT_WORK=true
      ;;
    --wait-for-all)
      WAIT_FOR_ALL=true
      ;;
    --no-validate)
      SKIP_VALIDATION=true
      ;;
    --no-threads|--no-thread|--simple-slack)
      SLACK_USE_THREADS=false
      THREADS_SET_BY_ARG=true
      ;;
    --no-slack)
      USE_SLACK=false
      SLACK_SET_BY_ARG=true
      ;;
    --slack-enable)
      USE_SLACK=true
      SLACK_SET_BY_ARG=true
      ;;
    --stream)
      STREAM_OUTPUT=true
      STREAM_SET_BY_ARG=true
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
      elif [ "${PREV_ARG}" = "--output-type" ]; then
        OUTPUT_TYPE="$arg"
      else
        # Only collect as positional if it looks like a number (avoid --typo as loop count)
        case "$arg" in
          --*) ;;
          *)   POSITIONAL_ARGS+=("$arg") ;;
        esac
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
    claude)         CLI_FLAGS="${PLAN_AN_GO_CLAUDE_FLAGS:-}" ;;
    cline)          CLI_FLAGS="${PLAN_AN_GO_CLINE_FLAGS:-}" ;;
    codex)          CLI_FLAGS="${PLAN_AN_GO_CODEX_FLAGS:-}" ;;
    copilot)        CLI_FLAGS="${PLAN_AN_GO_COPILOT_FLAGS:-}" ;;
    cursor-agent)   CLI_FLAGS="${PLAN_AN_GO_CURSOR_AGENT_FLAGS:-}" ;;
    droid)          CLI_FLAGS="${PLAN_AN_GO_DROID_FLAGS:-}" ;;
    gemini)         CLI_FLAGS="${PLAN_AN_GO_GEMINI_FLAGS:-}" ;;
    goose)          CLI_FLAGS="${PLAN_AN_GO_GOOSE_FLAGS:-}" ;;
    kiro)           CLI_FLAGS="${PLAN_AN_GO_KIRO_FLAGS:-}" ;;
    opencode)       CLI_FLAGS="${PLAN_AN_GO_OPENCODE_FLAGS:-}" ;;
    *)              CLI_FLAGS="" ;;
  esac
fi

# Normalize concurrency to a positive integer
CONCURRENCY=$(printf '%d' "$CONCURRENCY" 2>/dev/null || echo 1)
[ "$CONCURRENCY" -lt 1 ] && CONCURRENCY=1

# Normalize output type
case "$OUTPUT_TYPE" in
  json) ;;
  stdout) ;;
  *) OUTPUT_TYPE="stdout" ;;
esac

# Agent colors: build map from config or palette (after REPO_ROOT is set, see below)
RESET=$'\033[0m'
AGENT_COLORS_SCRIPT="$SCRIPT_DIR/scripts/agent-colors.sh"

# Export for child scripts (STREAM_OUTPUT, USE_SLACK re-exported after .env load below)
export PLAN_AN_GO_CLI="$CLI_BIN"
export PLAN_AN_GO_CLI_FLAGS="$CLI_FLAGS"

# Only use positionals that are positive integers; ignore typos/merged flags (e.g. --no-slacknpm)
if [[ "${POSITIONAL_ARGS[0]:-}" =~ ^[0-9]+$ ]] && [ "${POSITIONAL_ARGS[0]}" -gt 0 ]; then
  MAX_ITERATIONS="${POSITIONAL_ARGS[0]}"
else
  MAX_ITERATIONS=100
fi
if [[ "${POSITIONAL_ARGS[1]:-}" =~ ^[0-9]+$ ]] && [ "${POSITIONAL_ARGS[1]}" -gt 0 ]; then
  MAX_CHILD_LOOPS="${POSITIONAL_ARGS[1]}"
else
  MAX_CHILD_LOOPS=50
fi

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
# Load .env when script is run directly (entry script already loads it)
[ -f "$REPO_ROOT/.env" ] && set -a && . "$REPO_ROOT/.env" 2>/dev/null && set +a
# Re-apply env only if not overridden by command line (--slack-enable, --stream, --no-threads)
[ "$STREAM_SET_BY_ARG" != "true" ] && STREAM_OUTPUT="${PLAN_AN_GO_STREAM_OUTPUT:-${STREAM_OUTPUT:-false}}"
[ "$SLACK_SET_BY_ARG" != "true" ] && USE_SLACK="${PLAN_AN_GO_USE_SLACK:-${USE_SLACK:-false}}"
[ "$THREADS_SET_BY_ARG" != "true" ] && SLACK_USE_THREADS="${PLAN_AN_GO_SLACK_USE_THREADS:-${SLACK_USE_THREADS:-true}}"
ANTHROPIC_API_KEY="${PLAN_AN_GO_ANTHROPIC_API_KEY:-$ANTHROPIC_API_KEY}"
OPENAI_API_KEY="${PLAN_AN_GO_OPENAI_API_KEY:-$OPENAI_API_KEY}"
GEMINI_API_KEY="${PLAN_AN_GO_GEMINI_API_KEY:-${GEMINI_API_KEY:-$GOOGLE_API_KEY}}"
export ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY
export STREAM_OUTPUT USE_SLACK

# Build per-agent color map (from agents/config.json or palette) for Workers/completion output
if [ -f "$AGENT_COLORS_SCRIPT" ]; then
  . "$AGENT_COLORS_SCRIPT"
  build_agent_color_map "$CONCURRENCY" "$REPO_ROOT" 2>/dev/null || true
fi

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
PROGRESS_FILE="$TMP_DIR/progress.log"

# When workspace is under the script repo's tmp/, git commit from the implementer would write to the
# parent repo's .git and may fail (sandbox or permissions). Tell the implementer to skip commit.
SCRIPT_REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
case "$REPO_ROOT" in
  "$SCRIPT_REPO_ROOT"/tmp|"$SCRIPT_REPO_ROOT"/tmp/*) export PLAN_AN_GO_SKIP_COMMIT=true ;;
  *) unset -v PLAN_AN_GO_SKIP_COMMIT 2>/dev/null || true ;;
esac

# Display paths: relative when under REPO_ROOT for cleaner output
DISPLAY_PLAN="$PLAN_FILE"
DISPLAY_LOG="$LOG_FILE"
case "$PLAN_FILE" in "$REPO_ROOT"/*) DISPLAY_PLAN="./${PLAN_FILE#$REPO_ROOT/}"; esac
case "$LOG_FILE" in "$REPO_ROOT"/*) DISPLAY_LOG="./${LOG_FILE#$REPO_ROOT/}"; esac

# Validate CLI selection first (fail fast before plan file resolution)
case "$CLI_BIN" in
  claude|cline|copilot|codex|cursor-agent|droid|gemini|goose|kiro|opencode) ;;
  *)
    echo "❌ ERROR: --cli must be 'claude', 'cline', 'copilot', 'codex', 'cursor-agent', 'droid', 'gemini', 'goose', 'kiro', or 'opencode' (got: $CLI_BIN)" >&2
    exit 1
    ;;
esac

# If Slack enabled, require at least one token; otherwise disable and warn (do not exit)
if [ "$USE_SLACK" = "true" ]; then
  [ -f "$REPO_ROOT/.env" ] && set -a && source "$REPO_ROOT/.env" 2>/dev/null && set +a
  if [ -z "${PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN:-}" ] && [ -z "${SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${SLACK_APP_ACCESS_TOKEN:-}" ]; then
    echo "⚠️  Slack enabled but no Slack tokens set (PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN or PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN); disabling Slack." >&2
    USE_SLACK=false
  fi
fi

# Sound notifications (non-blocking; macOS afplay). Override with PLAN_AN_GO_SOUND_* env vars.
SOUND_ENABLED="${PLAN_AN_GO_SOUND_ENABLED:-true}"
SOUND_FILE="${PLAN_AN_GO_SOUND_TASK:-/System/Library/Sounds/Bottle.aiff}"
SOUND_FILE_FAIL="${PLAN_AN_GO_SOUND_FAIL:-/System/Library/Sounds/Funk.aiff}"
SOUND_FILE_PLAN_DONE="${PLAN_AN_GO_SOUND_PLAN_DONE:-/System/Library/Sounds/Hero.aiff}"

# Play task/iteration complete sound (macOS afplay; no-op if afplay missing)
play_sound() {
  if [ "$SOUND_ENABLED" = "true" ] && [ -f "${SOUND_FILE}" ] && command -v afplay &>/dev/null; then
    afplay "$SOUND_FILE" &
  fi
}

# Play failure sound (implementer failed, validator reverted, credits exhausted)
play_sound_fail() {
  if [ "$SOUND_ENABLED" = "true" ] && [ -f "${SOUND_FILE_FAIL}" ] && command -v afplay &>/dev/null; then
    afplay "$SOUND_FILE_FAIL" &
  fi
}

# Play plan-all-complete sound
play_sound_plan_done() {
  if [ "$SOUND_ENABLED" = "true" ] && [ -f "${SOUND_FILE_PLAN_DONE}" ] && command -v afplay &>/dev/null; then
    afplay "$SOUND_FILE_PLAN_DONE" &
  fi
}

# Spoken summary after each completed task (optional). Call with: impl_output val_output iteration confidence verdict
# No-op if PLAN_AN_GO_TTS_AFTER_TASK is not true or OPENAI_API_KEY is unset.
play_tts_after_task() {
  local impl_out="$1"
  local val_out="$2"
  local iter="${3:-0}"
  local conf="${4:-N/A}"
  local ver="${5:-PASSED}"
  local tts_after="${PLAN_AN_GO_TTS_AFTER_TASK:-${TTS_AFTER_TASK:-false}}"
  local openai_key="${PLAN_AN_GO_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}"
  [ "$tts_after" != "true" ] && return 0
  [ -z "$openai_key" ] && return 0
  local tts_script="$SCRIPT_DIR/plan-an-go-tts-summary.sh"
  [ ! -f "$tts_script" ] && return 0
  IMPL_OUTPUT="$impl_out" VAL_OUTPUT="$val_out" PLAN_FILE="$PLAN_FILE" \
    ITERATION="$iter" CONFIDENCE="$conf" VERDICT="$ver" \
    REPO_ROOT="$REPO_ROOT" PLAN_AN_GO_TMP="${TMP_DIR:-./tmp}" \
    PLAN_AN_GO_TTS_SUMMARY_PROMPT_FILE="${PLAN_AN_GO_TTS_SUMMARY_PROMPT_FILE:-${TTS_SUMMARY_PROMPT_FILE:-}}" \
    PLAN_AN_GO_TTS_SUMMARY_MODEL="${PLAN_AN_GO_TTS_SUMMARY_MODEL:-${TTS_SUMMARY_MODEL:-}}" \
    PLAN_AN_GO_TTS_TONE="${PLAN_AN_GO_TTS_TONE:-${TTS_TONE:-}}" \
    PLAN_AN_GO_TTS_VOICE="${PLAN_AN_GO_TTS_VOICE:-${TTS_VOICE:-}}" \
    PLAN_AN_GO_TTS_MODEL="${PLAN_AN_GO_TTS_MODEL:-${TTS_MODEL:-}}" \
    PLAN_AN_GO_TTS_SPEED="${PLAN_AN_GO_TTS_SPEED:-${TTS_SPEED:-}}" \
    OPENAI_API_KEY="$openai_key" \
    bash "$tts_script" 2>/dev/null || true
}

#═══════════════════════════════════════════════════════════════════════════════
# FAIL-EARLY VALIDATION
#═══════════════════════════════════════════════════════════════════════════════
# Resolve plan file to absolute path for all checks and child scripts.
# Relative paths are tried under workspace (REPO_ROOT) first; if not found, under script repo root
# so that --plan ./tmp/todo-tmp/PLAN.md works when run from repo root with --out-dir ./tmp/todo-tmp.
if [[ "$PLAN_FILE" != /* ]]; then
  candidate="$REPO_ROOT/$PLAN_FILE"
  if [ -f "$candidate" ]; then
    PLAN_FILE="$candidate"
  else
    script_repo="$(cd "$SCRIPT_DIR/../.." && pwd)"
    candidate="$script_repo/$PLAN_FILE"
    if [ -f "$candidate" ]; then
      PLAN_FILE="$candidate"
    else
      PLAN_FILE="$REPO_ROOT/$PLAN_FILE"
    fi
  fi
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

# <work> compliance: compliant = has <work>...</work> with at least one task line inside
WORK_COMPLIANT=false
WORK_SCRIPT="${SCRIPT_DIR:-.}/scripts/plan-work-section.sh"
if [ -f "$WORK_SCRIPT" ]; then
  if bash "$WORK_SCRIPT" compliant "$PLAN_FILE" 2>/dev/null; then
    WORK_COMPLIANT=true
  fi
fi
if [ "$WORK_COMPLIANT" = "false" ]; then
  echo "⚠️  WARNING: Plan is not <work>-compliant (missing <work>...</work> or no task lines inside)." >&2
  echo "   Search/extract/update may match prompt or example text. See README for required format." >&2
  if [ "$STRICT_WORK" = "true" ]; then
    echo "❌ ERROR: Refusing to run with --strict. Wrap milestones and tasks in <work>...</work>." >&2
    exit 1
  fi
  echo "" >&2
fi
[ "$STRICT_WORK" = "true" ] && export PLAN_AN_GO_STRICT=true || export PLAN_AN_GO_STRICT=false

# Ensure progress log exists under tmp
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Progress Log - $(date '+%Y-%m-%d %H:%M:%S')" > "$PROGRESS_FILE"
fi

# Validate selected CLI is available
if ! command -v "$CLI_BIN" &> /dev/null; then
  echo "❌ ERROR: '$CLI_BIN' CLI not found in PATH" >&2
  case "$CLI_BIN" in
    claude)   echo "Install: https://docs.anthropic.com/claude/docs/claude-cli" >&2 ;;
    cline)   echo "Install: https://docs.cline.bot/cline-cli/getting-started" >&2 ;;
    copilot) echo "Install: https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-in-the-cli" >&2 ;;
    droid)   echo "Install: https://app.factory.ai/cli" >&2 ;;
    gemini)   echo "Install: https://github.com/google-gemini/gemini-cli" >&2 ;;
    goose)   echo "Install: https://github.com/block/goose" >&2 ;;
    kiro)    echo "Install: https://cli.kiro.dev/" >&2 ;;
    opencode) echo "Install: https://github.com/opencode-ai/opencode" >&2 ;;
    *)       ;;
  esac
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

# If Slack enabled and output contains Fatal or ERROR, post a dedicated error alert (custom message + Error emoji).
post_slack_error_alert_if_needed() {
  [ "$USE_SLACK" != "true" ] && return 0
  local output="${1:-}"
  local source_label="${2:-Output}"
  if [ -n "$output" ] && echo "$output" | grep -qiE "Fatal|ERROR"; then
    post_slack_message "🚨 *Error in iteration $iteration* ($source_label) — Fatal or errors detected. Check pipeline logs for details." "$PIPELINE_THREAD_TS"
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

# Strip checkbox and [IN_PROGRESS]:[AGENT_NN] for display; keep milestone:task ID and description (matches plan)
format_task_line_for_display() {
  local line="$1"
  line="${line#- [ ] }"
  line="${line#\[  \] - }"
  line="${line#\[ \] - }"
  echo "$line" | sed -e 's/ \[IN_PROGRESS\]:\[AGENT_[0-9]*\]$//' -e 's/ \[IN_PROGRESS\]$//'
}

# Format task line as "M<n> - M<n>:<id> - <description>" for "In Progress:" line
format_in_progress_line() {
  local raw="$1"
  if [[ "$raw" =~ ^(M[0-9]+):([0-9]+(\.[0-9]+)*)-[[:space:]]*(.*) ]]; then
    echo "${BASH_REMATCH[1]} - ${BASH_REMATCH[1]}:${BASH_REMATCH[2]} - ${BASH_REMATCH[4]}"
  else
    echo "$raw"
  fi
}

# Escape string for JSON value (backslash and double-quote).
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Emit one JSON object to stdout (when OUTPUT_TYPE=json). Event types: pipeline_start, iteration_end, pipeline_end.
emit_json() {
  [ "$OUTPUT_TYPE" != "json" ] && return
  local event="$1"
  shift
  local plan_esc cli_esc started_esc
  case "$event" in
    pipeline_start)
      plan_esc=$(json_escape "${DISPLAY_PLAN:-$PLAN_FILE}")
      cli_esc=$(json_escape "$CLI_BIN")
      started_esc=$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "unknown")
      printf '{"event":"pipeline_start","plan":"%s","cli":"%s","concurrency":%s,"max_iterations":%s,"started_at":"%s","validation":%s}\n' \
        "$plan_esc" "$cli_esc" "$CONCURRENCY" "$MAX_ITERATIONS" "$started_esc" "$([ "$SKIP_VALIDATION" = "true" ] && echo "false" || echo "true")"
      ;;
    iteration_end)
      plan_esc=$(json_escape "${current_plan_status:-}")
      printf '{"event":"iteration_end","iteration":%s,"duration_sec":%s,"plan_status":"%s","verdict":"%s","confidence":"%s","eta_sec":%s}\n' \
        "$iteration" "$iter_duration" "$plan_esc" "$verdict" "$confidence" "$eta"
      ;;
    pipeline_end)
      plan_esc=$(json_escape "${current_plan_status:-}")
      printf '{"event":"pipeline_end","reason":"%s","iterations":%s,"total_sec":%s,"plan_status":"%s"}\n' \
        "$1" "$iteration" "$2" "$plan_esc"
      ;;
    *) ;;
  esac
}

# Get task description for agent from plan (line with [IN_PROGRESS]:[agent_id]). Uses work_awk_cond from caller.
get_agent_task_line() {
  local plan_file="$1"
  local agent_id="$2"
  local work_awk="$3"
  local line
  line=$(grep -n "\[IN_PROGRESS\]:\[${agent_id}\]" "$plan_file" 2>/dev/null | awk "$work_awk" | head -1 | sed 's/^[0-9]*://')
  [ -z "$line" ] && echo "" && return
  format_task_line_for_display "$line"
}

# Output one "start end" per line for each <work>...</work> block (plan may have multiple blocks).
# If no <work> or script missing, outputs "1 <last_line>" for backward compatibility.
get_work_section_bounds() {
  local f="${1:-}"
  [ ! -f "$f" ] && echo "1 1" && return
  local last_line
  last_line=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  [ -z "$last_line" ] && last_line=1
  local script="${SCRIPT_DIR:-.}/scripts/plan-work-section.sh"
  if [ -f "$script" ]; then
    local out
    out=$(bash "$script" bounds "$f" 2>/dev/null) || true
    [ -n "$out" ] && echo "$out" || echo "1 $last_line"
  else
    echo "1 $last_line"
  fi
}

# Build an awk condition from get_work_section_bounds output for filtering grep -n by line number.
# Usage: work_awk_cond=$(build_work_bounds_awk_condition "$(get_work_section_bounds "$plan_file")")
# Then: grep -n ... | awk "$work_awk_cond"
build_work_bounds_awk_condition() {
  local bounds="$1"
  echo "$bounds" | awk '{printf "%s($1>=%s&&$1<=%s)", (NR>1?"||":""), $1, $2}'
}

# Programmatic task count verification
# Returns: "COMPLETE" if all tasks done, or "X incomplete" count
# Only counts task lines inside <work>...</work> when present.
verify_plan_completion() {
  local plan_file="${1:-PLAN.md}"
  
  if [ ! -f "$plan_file" ]; then
    echo "PLAN_NOT_FOUND"
    return 1
  fi

  local work_bounds work_awk_cond
  work_bounds=$(get_work_section_bounds "$plan_file")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  
  # Count only lines inside work section(s); task lines: "[ ] - M<n>:..." or "[  ] - M<n>:..." or template
  local template_incomplete
  template_incomplete=$(grep -n '^\- \[ \] \*\*' "$plan_file" 2>/dev/null | awk "$work_awk_cond" | wc -l | tr -d ' ')
  template_incomplete=${template_incomplete:-0}
  local bracket_incomplete
  bracket_incomplete=$(grep -n -E '^\[ \] - M[0-9]+:|^\[  \] - M[0-9]+:' "$plan_file" 2>/dev/null | awk "$work_awk_cond" | wc -l | tr -d ' ')
  bracket_incomplete=${bracket_incomplete:-0}
  local all_incomplete=$((template_incomplete + bracket_incomplete))
  
  local check_tasks
  check_tasks=$(grep -n '^\- \[ \] \*\*CHECK\.' "$plan_file" 2>/dev/null | awk "$work_awk_cond" | wc -l | tr -d ' ')
  check_tasks=${check_tasks:-0}
  
  local ui_incomplete
  ui_incomplete=$(grep -n '^\- \[x\] \[UI\]' "$plan_file" 2>/dev/null | awk "$work_awk_cond" | wc -l | tr -d ' ')
  ui_incomplete=${ui_incomplete:-0}
  
  local func_incomplete
  func_incomplete=$(grep -n '^\- \[x\] \[FUNCTIONAL\]' "$plan_file" 2>/dev/null | awk "$work_awk_cond" | wc -l | tr -d ' ')
  func_incomplete=${func_incomplete:-0}
  
  # Implementation tasks = all incomplete minus CHECK tasks
  local impl_incomplete=$((all_incomplete - check_tasks))
  
  # Total truly incomplete = implementation tasks + [UI]/[FUNCTIONAL] tagged tasks
  local total_incomplete=$((impl_incomplete + ui_incomplete + func_incomplete))
  
  if [ "$total_incomplete" -eq 0 ]; then
    echo "COMPLETE"
  else
    echo "$total_incomplete incomplete"
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

# Write [IN_PROGRESS] to the first *eligible* incomplete task line (concurrency=1).
# Eligible = no dependency hint, or dependency task is marked [x]. Only considers lines inside <work>...</work> (any block).
mark_first_incomplete_in_progress() {
  local f="${1:-$PLAN_FILE}"
  [ ! -f "$f" ] && return 0
  local work_bounds work_awk_cond
  work_bounds=$(get_work_section_bounds "$f")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  local first_ln=""
  while IFS= read -r rec; do
    [ -z "$rec" ] && continue
    local ln="${rec%%:*}"
    local line="${rec#*:}"
    local dep
    dep=$(get_dependency_from_task_line "$line")
    if [ -n "$dep" ]; then
      is_task_complete_in_plan "$f" "$dep" || continue
    fi
    first_ln="$ln"
    break
  done < <(grep -n -E '^(\- \[ \] \*\*|\[ \] - M[0-9]+:|\[  \] - M[0-9]+:)' "$f" 2>/dev/null | awk "$work_awk_cond")
  if [ -n "$first_ln" ]; then
    sed "${first_ln}s/$/ [IN_PROGRESS]/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    ensure_plan_trailing_newline "$f"
  fi
}

# Extract dependency task ID from a task line if present.
# Looks for (after M<n>:<id>), (requires M<n>:<id>), or (when M<n>:<id> complete). Outputs e.g. M1:2 or empty.
get_dependency_from_task_line() {
  local line="$1"
  local dep
  dep=$(echo "$line" | grep -oE '\((after|requires|when) M[0-9]+:[0-9A-Za-z.]+\)' 2>/dev/null | head -1)
  if [ -n "$dep" ]; then
    echo "$dep" | sed 's/.*(after\|requires\|when) //' | tr -d ')'
  fi
}

# Return 0 if the given task_id is marked complete ([x]) in the plan file, else 1.
is_task_complete_in_plan() {
  local f="$1"
  local task_id="$2"
  [ ! -f "$f" ] && return 1
  local tid_esc
  tid_esc=$(echo "$task_id" | sed 's/\./\\./g')
  grep -qE "\[x\].*${tid_esc}-" "$f" 2>/dev/null
}

# Write [IN_PROGRESS]:[AGENT_01] ... [IN_PROGRESS]:[AGENT_N] to the first N *eligible* incomplete task lines.
# Eligible = no dependency hint, or dependency task is marked [x]. Skips tasks whose dependency is not yet complete.
mark_next_n_incomplete_in_progress() {
  local f="${1:-$PLAN_FILE}"
  local n="${2:-1}"
  [ ! -f "$f" ] && return 0
  [ "$n" -lt 1 ] && return 0
  local work_bounds work_awk_cond
  work_bounds=$(get_work_section_bounds "$f")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  local eligible_lns=()
  while IFS= read -r rec; do
    [ -z "$rec" ] && continue
    local ln="${rec%%:*}"
    local line="${rec#*:}"
    local dep
    dep=$(get_dependency_from_task_line "$line")
    if [ -n "$dep" ]; then
      is_task_complete_in_plan "$f" "$dep" || continue
    fi
    eligible_lns+=("$ln")
    [ ${#eligible_lns[@]} -ge "$n" ] && break
  done < <(grep -n -E '^(\- \[ \] \*\*|\[ \] - M[0-9]+:|\[  \] - M[0-9]+:)' "$f" 2>/dev/null | awk "$work_awk_cond")
  [ ${#eligible_lns[@]} -eq 0 ] && return 0
  local idx=1
  local sed_expr=""
  for ln in "${eligible_lns[@]}"; do
    agent_id=$(printf 'AGENT_%02d' "$idx")
    sed_expr="${sed_expr}${sed_expr:+;}${ln}s/\$/ [IN_PROGRESS]:[${agent_id}]/"
    idx=$(( idx + 1 ))
  done
  sed "$sed_expr" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  ensure_plan_trailing_newline "$f"
}

# Mark the first eligible incomplete task (no [IN_PROGRESS] yet) with [IN_PROGRESS]:[agent_id].
# Eligible = no dependency or dependency is [x]. Returns 0 if a task was marked, 1 if none left.
mark_one_incomplete_with_agent() {
  local f="${1:-$PLAN_FILE}"
  local agent_id="$2"
  [ ! -f "$f" ] && return 1
  local work_bounds work_awk_cond
  work_bounds=$(get_work_section_bounds "$f")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  local ln line dep
  while IFS= read -r rec; do
    [ -z "$rec" ] && continue
    ln="${rec%%:*}"
    line="${rec#*:}"
    if echo "$line" | grep -q '\[IN_PROGRESS\]'; then continue; fi
    dep=$(get_dependency_from_task_line "$line")
    if [ -n "$dep" ]; then
      is_task_complete_in_plan "$f" "$dep" || continue
    fi
    sed "${ln}s/$/ [IN_PROGRESS]:[${agent_id}]/" "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
    ensure_plan_trailing_newline "$f"
    return 0
  done < <(grep -n -E '^(\- \[ \] \*\*|\[ \] - M[0-9]+:|\[  \] - M[0-9]+:)' "$f" 2>/dev/null | awk "$work_awk_cond")
  return 1
}

# Sum CPU % and RSS (KB) for pid and its direct children. Output: "cpu rss_kb" (space-separated).
get_pid_cpu_mem() {
  local p=$1
  local list
  list="$p"
  while read -r c; do [ -n "$c" ] && list="$list $c"; done < <(pgrep -P "$p" 2>/dev/null)
  # ps -p expects comma-separated list on macOS
  list=$(echo "$list" | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
  [ -z "$list" ] && printf "0 0" && return
  ps -o '%cpu=' -o 'rss=' -p "$list" 2>/dev/null | awk '{ cpu += $1 + 0; rss += $2 + 0 } END { printf "%.1f %d", cpu + 0, rss + 0 }'
}

# Wait for multiple PIDs; print one line when done with elapsed time. Usage: wait_pids_multi "Message" pid1 pid2 ...
wait_pids_multi() {
  local msg="$1"
  shift
  local pids=("$@")
  local start elapsed
  start=$(date +%s)
  while true; do
    for p in "${pids[@]}"; do
      kill -0 "$p" 2>/dev/null && { sleep 0.5; continue 2; }
    done
    break
  done
  elapsed=$(($(date +%s) - start))
  printf "  ✓ %s · Elapsed: %ds\n" "$msg" "$elapsed" >&2
}

# Wait for PID; print one line when done with CPU/Mem. No animation.
wait_pid_with_stats() {
  local pid=$1
  local msg=$2
  local start elapsed stats cpu rss_mb
  start=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do sleep 0.5; done
  elapsed=$(($(date +%s) - start))
  stats=$(get_pid_cpu_mem "$pid" 2>/dev/null) || true
  cpu="0"
  rss_mb=0
  if [ -n "$stats" ]; then
    cpu="${stats%% *}"
    [ -z "$cpu" ] && cpu="0"
    [ "${stats#* }" != "$stats" ] && rss_mb=$((${stats#* } / 1024))
  fi
  printf "  ✓ %s · Elapsed: %ds · CPU %s%% · %d MB\n" "$msg" "$elapsed" "$cpu" "$rss_mb" >&2
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
PLAN_CHECK_SCRIPT="$SCRIPT_DIR/plan-an-go-plan-check.sh"
header_plan_check=""
[ -f "$PLAN_CHECK_SCRIPT" ] && header_plan_check=$([ -x "$PLAN_CHECK_SCRIPT" ] && "$PLAN_CHECK_SCRIPT" "$PLAN_FILE" 2>/dev/null || bash "$PLAN_CHECK_SCRIPT" "$PLAN_FILE" 2>/dev/null) || true
header_milestones=""
header_tasks=""
header_complete=""
header_incomplete=""
header_subtasks=""
if [ -n "$header_plan_check" ]; then
  header_milestones=$(echo "$header_plan_check" | sed -n 's/.*Milestones:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  header_tasks=$(echo "$header_plan_check" | sed -n 's/.*Tasks:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  header_complete=$(echo "$header_plan_check" | sed -n 's/.*Complete:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  header_incomplete=$(echo "$header_plan_check" | sed -n 's/.*Incomplete:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  header_subtasks=$(echo "$header_plan_check" | sed -n 's/.*Subtasks:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
fi
[ -z "$header_tasks" ] && header_tasks="?"
[ -z "$header_complete" ] && header_complete="?"
[ -z "$header_incomplete" ] && header_incomplete="?"
[ -z "$header_milestones" ] && header_milestones="?"
[ -z "$header_subtasks" ] && header_subtasks="0"

# Resolve CLI model for display (Config/Agents block)
CLI_MODEL_DISPLAY="default"
case "$CLI_BIN" in
  claude)  [ -n "${PLAN_AN_GO_CLAUDE_MODEL:-}" ] && CLI_MODEL_DISPLAY="$PLAN_AN_GO_CLAUDE_MODEL" ;;
  codex)   [ -n "${PLAN_AN_GO_CODEX_MODEL:-}" ] && CLI_MODEL_DISPLAY="$PLAN_AN_GO_CODEX_MODEL" ;;
  gemini)  [ -n "${PLAN_AN_GO_GEMINI_MODEL:-}" ] && CLI_MODEL_DISPLAY="$PLAN_AN_GO_GEMINI_MODEL" ;;
  opencode) [ -n "${PLAN_AN_GO_OPENCODE_MODEL:-}" ] && CLI_MODEL_DISPLAY="$PLAN_AN_GO_OPENCODE_MODEL" ;;
  *)       [ -n "${PLAN_AN_GO_CURSOR_AGENT_MODEL:-}" ] && CLI_MODEL_DISPLAY="$PLAN_AN_GO_CURSOR_AGENT_MODEL" ;;
esac

# Print minimal-format header (matches tmp/minimal): version, config, agents, swarm, tasks summary, task table.
print_minimal_header() {
  local ref_plan="${1:-$PLAN_FILE}"
  local ref_display="${2:-$DISPLAY_PLAN}"
  local ref_status="${3:-$initial_plan_status}"
  local ref_ts
  ref_ts=$(date '+%Y-%m-%d %H:%M:%S')
  local pkg_json="${SCRIPT_DIR:-.}/../package.json"
  local ver="1.0.0"
  [ -f "$pkg_json" ] && command -v node &>/dev/null && ver=$(node -p "require('$pkg_json').version" 2>/dev/null) || ver="1.0.0"
  echo "PLAN-TO-GO - Version $ver (minimal mode)"
  printf "PRD Task Watcher                                               %s\n" "$ref_ts"
  echo "+----------+-----+-------------------------------------------------------+"
  echo "Config:"
  echo "    - Plan: $ref_display"
  echo "    - Last refresh: $ref_ts"
  echo "    - CLI: $CLI_BIN"
  echo "    - CLI model: $CLI_MODEL_DISPLAY"
  echo "Agents:"
  local a
  for a in $(seq 1 "$CONCURRENCY"); do
    echo "  - AGENT_$(printf '%02d' "$a")"
    echo "    - CLI: $CLI_BIN"
    echo "    - CLI model: $CLI_MODEL_DISPLAY"
    echo "    - CLI flags: ${CLI_FLAGS:-none}"
  done
  if [ "$CONCURRENCY" -gt 1 ]; then
    echo "Swarm:"
    echo " - SWARM_01"
    for a in $(seq 1 "$CONCURRENCY"); do
      echo "    - AGENT_$(printf '%02d' "$a")"
      echo "        - CLI: $CLI_BIN"
      echo "        - CLI model: $CLI_MODEL_DISPLAY"
      echo "        - CLI flags: ${CLI_FLAGS:-none}"
    done
  fi
  local pct="0"
  [ "${header_tasks:-0}" -gt 0 ] 2>/dev/null && pct=$(awk "BEGIN { printf \"%.1f\", (${header_complete:-0} * 100) / ${header_tasks:-1} }")
  echo "Tasks Summary:"
  echo "    - Milestones: ${header_milestones:-?}"
  echo "    - Tasks: ${header_tasks:-?}"
  echo "    - Subtasks: ${header_subtasks:-0}"
  echo "    - Complete: ${header_complete:-?}"
  echo "    - Incomplete: ${header_incomplete:-?}"
  echo "    - Progress: ${pct}%"
  echo "+----------+---+---------------------------------------------------------+"
  echo "Status: $ref_status"
  echo "+----------+---+---------------------------------------------------------+"
  echo "ID         |   | Task summary"
  echo "+----------+---+---------------------------------------------------------+"
  local work_bounds work_awk_cond
  work_bounds=$(get_work_section_bounds "$ref_plan")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  grep -n -E '^(\[x\] *- *M[0-9]+:|\[[ ]+\] *- *M[0-9]+:)' "$ref_plan" 2>/dev/null | awk "$work_awk_cond" | sed 's/^[0-9]*://' | while IFS= read -r line; do
    local id="" done_sym="o" desc=""
    if echo "$line" | grep -q '^\[x\]'; then
      done_sym="✓"
    fi
    id=$(echo "$line" | sed -n 's/.*\(M[0-9]*:[0-9A-Za-z.]*\).*/\1/p' | head -1)
    desc=$(echo "$line" | sed -E 's/^\[[x ]+\] *- *M[0-9]+:[0-9A-Za-z.]*-[[:space:]]*//' | sed 's/ \[IN_PROGRESS\].*//' | sed 's/ \[AGENT_[0-9]*\]//g')
    [ ${#desc} -gt 42 ] && desc="${desc:0:39}..."
    summary="${id:-?} - $desc"
    printf "%-10s | %s | %s\n" "${id:-?}" "$done_sym" "$summary"
  done
  echo "+----------+-----+---------------------------------------------------------+"
  echo "Last refresh: $ref_ts"
  echo "+----------+-----+---------------------------------------------------------+"
}

if [ "$OUTPUT_TYPE" = "json" ]; then
  emit_json pipeline_start
else
  print_minimal_header "$PLAN_FILE" "$DISPLAY_PLAN" "$initial_plan_status"
  echo "  Ctrl+C to stop after current iteration"
  echo ""
fi

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
PLAN_CHECK_SCRIPT="$SCRIPT_DIR/plan-an-go-plan-check.sh"
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
  IMPL_OUTPUT_SHOWN=false
  VAL_OUTPUT_SHOWN=false
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
  elif [ "$WAIT_FOR_ALL" = "true" ]; then
    mark_next_n_incomplete_in_progress "$PLAN_FILE" "$CONCURRENCY"
  fi
  # When CONCURRENCY > 1 and pool mode (WAIT_FOR_ALL=false), tasks are assigned in the pool loop below.
  
  #─────────────────────────────────────────────────────────────────────────────
  # Plan status: minimal format (Counts, Completion, then In Progress block)
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$QUIET" != "true" ] && [ -f "$PLAN_CHECK_SCRIPT" ]; then
    plan_check_out=$([ -x "$PLAN_CHECK_SCRIPT" ] && "$PLAN_CHECK_SCRIPT" "$PLAN_FILE" 2>/dev/null || bash "$PLAN_CHECK_SCRIPT" "$PLAN_FILE" 2>/dev/null) || true
    if [ -n "$plan_check_out" ]; then
      echo "$plan_check_out" | sed -n '/2\. Counts/,/4\. Formatting/p' | sed '/4\. Formatting/d'
    fi
  fi

  #─────────────────────────────────────────────────────────────────────────────
  # STAGE 1: IMPLEMENTER AGENT(S)
  #─────────────────────────────────────────────────────────────────────────────
  # Show the task(s) actually in progress (lines with [IN_PROGRESS] or [IN_PROGRESS]:[AGENT_NN])
  work_bounds=$(get_work_section_bounds "$PLAN_FILE")
  work_awk_cond=$(build_work_bounds_awk_condition "$work_bounds")
  task_parts=()
  if [ "$CONCURRENCY" -eq 1 ]; then
    while IFS= read -r task_line; do
      [ -z "$task_line" ] && continue
      task_parts+=("$(format_task_line_for_display "$task_line")")
      break
    done < <(grep -n '\[IN_PROGRESS\]' "$PLAN_FILE" 2>/dev/null | awk "$work_awk_cond" | head -1 | sed 's/^[0-9]*://')
  else
    for a in $(seq 1 "$CONCURRENCY"); do
      agent_id=$(printf 'AGENT_%02d' "$a")
      while IFS= read -r task_line; do
        [ -z "$task_line" ] && continue
        task_parts+=("$(format_task_line_for_display "$task_line")")
        break
      done < <(grep -n "\[IN_PROGRESS\]:\[${agent_id}\]" "$PLAN_FILE" 2>/dev/null | awk "$work_awk_cond" | head -1 | sed 's/^[0-9]*://')
    done
  fi
  if [ ${#task_parts[@]} -eq 0 ]; then
    while IFS= read -r task_line; do
      [ -z "$task_line" ] && continue
      task_parts+=("$(format_task_line_for_display "$task_line")")
    done < <(grep -n -E '^(\- \[ \] \*\*|\[ \] - M[0-9]+:|\[  \] - M[0-9]+:)' "$PLAN_FILE" 2>/dev/null | awk "$work_awk_cond" | sed 's/^[0-9]*://' | head -n "$CONCURRENCY")
  fi

  # Minimal-format "In Progress" block (box separator + Workers-style lines)
  if [ "$OUTPUT_TYPE" != "json" ] && [ "$QUIET" != "true" ] && [ ${#task_parts[@]} -gt 0 ]; then
    echo "Now: Implementer is working on the task below. When done we mark it complete and continue to the next."
    echo ""
    echo "In Progress:"
    for i in "${!task_parts[@]}"; do
      formatted=$(format_in_progress_line "${task_parts[$i]}")
      if [[ "$formatted" == *"<Task description>"* ]] || [[ "$formatted" == *"<Subtask>"* ]]; then
        formatted="${formatted/<Task description>/[add real description in PLAN.md]}"
        formatted="${formatted/<Subtask>/[add real description in PLAN.md]}"
      fi
      if [ "$CONCURRENCY" -eq 1 ]; then
        echo "  $formatted"
      else
        echo "  Agent $((i + 1)): $formatted"
      fi
    done
    echo ""
  fi

  if [ "$CONCURRENCY" -eq 1 ]; then
    if [ "$STREAM_OUTPUT" = "true" ]; then
      [ "$QUIET" != "true" ] && echo "Streaming implementer..."
      if [ -n "$TAIL_LOG" ]; then
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$IMPL_SCRIPT" 2>&1 | tee "$impl_output" | tee -a "$TAIL_LOG"
        IMPL_OUTPUT_SHOWN=true
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$IMPL_SCRIPT" 2>&1 | tee "$impl_output"
        IMPL_OUTPUT_SHOWN=true
      fi
      impl_exit=${PIPESTATUS[0]}
    else
      if [ -n "$TAIL_LOG" ]; then
        # --tail: show implementer output on screen and append to tail log (no spinner)
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$IMPL_SCRIPT" 2>&1 | tee "$impl_output" | tee -a "$TAIL_LOG"
        impl_exit=${PIPESTATUS[0]}
        IMPL_OUTPUT_SHOWN=true
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$IMPL_SCRIPT" > "$impl_output" 2>&1 &
        impl_pid=$!
        if [ "$QUIET" = "true" ]; then wait $impl_pid; else wait_pid_with_stats $impl_pid "Implementer working"; wait $impl_pid; fi
        impl_exit=$?
      fi
    fi
  else
    # CONCURRENCY > 1: run N implementers
    if [ "$WAIT_FOR_ALL" = "true" ]; then
      # Wait-for-all: N tasks already marked above; wait for all N to finish, then next iteration.
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
      if [ "$QUIET" = "true" ]; then
        for p in "${impl_pids[@]}"; do wait "$p" || impl_exit=$?; done
      else
        wait_pids_multi "Waiting for $CONCURRENCY implementers" "${impl_pids[@]}"
        for p in "${impl_pids[@]}"; do wait "$p" || impl_exit=$?; done
      fi
      for f in "${impl_outputs[@]}"; do
        [ -f "$f" ] && mark_task_complete_from_implementer_output "$f" "$PLAN_FILE"
      done
      cat "${impl_outputs[@]}" > "$impl_output" 2>/dev/null || true
      rm -f "${impl_outputs[@]}"
    else
      # Pool mode (default): when an agent finishes it immediately takes the next task until no work left.
      strip_in_progress_from_file "$PLAN_FILE"
      > "$impl_output"
      impl_exit=0
      slot_pid=()
      slot_out=()
      pool_start=$(date +%s)
      pool_completed=$(mktemp "$TMP_DIR/forever-pool-completed.XXXXXX")
      for idx in $(seq 0 $((CONCURRENCY - 1))); do
        agent_id=$(printf 'AGENT_%02d' "$((idx + 1))")
        slot_last_cpu[$idx]="0"
        slot_last_rss_mb[$idx]=0
        if mark_one_incomplete_with_agent "$PLAN_FILE" "$agent_id"; then
          out_f=$(mktemp "$TMP_DIR/forever-agent.XXXXXX")
          slot_out[$idx]="$out_f"
          PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS PLAN_AN_GO_AGENT_ID="$agent_id" "$IMPL_SCRIPT" > "$out_f" 2>&1 &
          slot_pid[$idx]=$!
        else
          slot_pid[$idx]=""
          slot_out[$idx]=""
        fi
      done
      any_running() {
        local j
        for j in $(seq 0 $((CONCURRENCY - 1))); do
          [ -n "${slot_pid[$j]:-}" ] && kill -0 "${slot_pid[$j]}" 2>/dev/null && return 0
        done
        return 1
      }
      last_workers_print=0
      # Portable "wait for any child": wait -n is Bash 4.3+ and not available on macOS (Bash 3.2)
      while any_running; do
        found=0
        for j in $(seq 0 $((CONCURRENCY - 1))); do
          [ -z "${slot_pid[$j]:-}" ] && continue
          if ! kill -0 "${slot_pid[$j]}" 2>/dev/null; then
            agent_id=$(printf 'AGENT_%02d' "$((j + 1))")
            task_line=$(get_agent_task_line "$PLAN_FILE" "$agent_id" "$work_awk_cond")
            completed_cpu="${slot_last_cpu[$j]:-0}"
            completed_rss="${slot_last_rss_mb[$j]:-0}"
            printf "%s\t%s\t%s\t%s\n" "$agent_id" "$completed_cpu" "$completed_rss" "$task_line" >> "$pool_completed"
            slot_exit=0
            wait "${slot_pid[$j]}" 2>/dev/null || slot_exit=$?
            [ $slot_exit -ne 0 ] && impl_exit=$slot_exit
            [ -f "${slot_out[$j]:-}" ] && mark_task_complete_from_implementer_output "${slot_out[$j]}" "$PLAN_FILE"
            [ -f "${slot_out[$j]:-}" ] && cat "${slot_out[$j]}" >> "$impl_output"
            strip_in_progress_from_completed_lines "$PLAN_FILE"
            slot_pid[$j]=""
            agent_id=$(printf 'AGENT_%02d' "$((j + 1))")
            if mark_one_incomplete_with_agent "$PLAN_FILE" "$agent_id"; then
              out_f=$(mktemp "$TMP_DIR/forever-agent.XXXXXX")
              slot_out[$j]="$out_f"
              PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS PLAN_AN_GO_AGENT_ID="$agent_id" "$IMPL_SCRIPT" > "$out_f" 2>&1 &
              slot_pid[$j]=$!
            fi
            found=1
            break
          fi
        done
        if [ "$found" -eq 0 ] && [ "$QUIET" != "true" ] && [ "$OUTPUT_TYPE" != "json" ]; then
          now=$(date +%s)
          if [ $((now - last_workers_print)) -ge 3 ]; then
            last_workers_print=$now
            echo "+----------+-----+---------------------------------------------------------+" >&2
            echo "Workers:" >&2
            for j in $(seq 0 $((CONCURRENCY - 1))); do
              [ -z "${slot_pid[$j]:-}" ] && continue
              kill -0 "${slot_pid[$j]}" 2>/dev/null || continue
              agent_id=$(printf 'AGENT_%02d' "$((j + 1))")
              ac=""
              [ -f "$AGENT_COLORS_SCRIPT" ] && ac=$(get_agent_color "$agent_id")
              stats=$(get_pid_cpu_mem "${slot_pid[$j]}" 2>/dev/null) || stats="0 0"
              cpu="${stats%% *}"
              rss_mb=0
              [ "${stats#* }" != "$stats" ] && rss_mb=$((${stats#* } / 1024))
              slot_last_cpu[$j]="$cpu"
              slot_last_rss_mb[$j]=$rss_mb
              task_line=$(get_agent_task_line "$PLAN_FILE" "$agent_id" "$work_awk_cond")
              printf "%s[IN_PROGRESS]:[%s]%s · CPU %s%% · %d MB\n" "$ac" "$agent_id" "$RESET" "$cpu" "$rss_mb" >&2
              if [ -n "$task_line" ]; then
                [ "$HIGHLIGHT_AGENTS" = "true" ] && [ -n "$ac" ] && printf "%s - %s%s\n" "$ac" "$task_line" "$RESET" >&2 || printf " - %s\n" "$task_line" >&2
              fi
            done
            echo "+----------+-----+---------------------------------------------------------+" >&2
          fi
        fi
        [ "$found" -eq 0 ] && sleep 0.5
      done
      [ "$QUIET" != "true" ] && [ "$OUTPUT_TYPE" != "json" ] && printf "  ✓ Pool done · %ds\n" "$(($(date +%s) - pool_start))" >&2
      if [ "$QUIET" != "true" ] && [ "$OUTPUT_TYPE" != "json" ] && [ -f "$pool_completed" ] && [ -s "$pool_completed" ]; then
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          agent_id=$(echo "$line" | cut -f1)
          completed_cpu=$(echo "$line" | cut -f2)
          completed_rss=$(echo "$line" | cut -f3)
          task_line=$(echo "$line" | cut -f4-)
          [ -z "$task_line" ] && task_line="(task completed)"
          ac=""
          [ -f "$AGENT_COLORS_SCRIPT" ] && ac=$(get_agent_color "$agent_id")
          echo "+----------+-----+---------------------------------------------------------+" >&2
          printf "%s[COMPLETE]:[%s]%s · CPU %s%% · %s MB\n" "$ac" "$agent_id" "$RESET" "$completed_cpu" "$completed_rss" >&2
          if [ "$HIGHLIGHT_AGENTS" = "true" ] && [ -n "$ac" ]; then
            printf "%s    - Task: ✓ %s%s\n" "$ac" "$task_line" "$RESET" >&2
          else
            printf "    - Task: ✓ %s\n" "$task_line" >&2
          fi
          echo "+----------+-----+---------------------------------------------------------+" >&2
        done < "$pool_completed"
      fi
      [ -f "$pool_completed" ] && rm -f "$pool_completed"
      for idx in $(seq 0 $((CONCURRENCY - 1))); do
        [ -f "${slot_out[$idx]:-}" ] && rm -f "${slot_out[$idx]}"
      done
    fi
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
    play_sound_fail
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
  
  if [ "$STREAM_OUTPUT" != "true" ] && [ "$QUIET" != "true" ] && [ "$IMPL_OUTPUT_SHOWN" != "true" ]; then
    echo ""
    echo "$impl_result"
  fi
  
  impl_summary=$(extract_summary "$impl_result" "IMPLEMENTER")
  impl_summary=$(printf '%s' "$impl_summary" | tr -d '`')
  impl_slack_msg=$(printf '📝 *IMPLEMENTER*\n```\n%s\n```' "$impl_summary")
  post_slack_message "$impl_slack_msg" "$PIPELINE_THREAD_TS"
  post_slack_error_alert_if_needed "$impl_result" "Implementer"

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
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$VAL_SCRIPT" "$impl_output" 2>&1 | tee "$val_output" | tee -a "$TAIL_LOG"
        VAL_OUTPUT_SHOWN=true
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS STREAM_OUTPUT=true "$VAL_SCRIPT" "$impl_output" 2>&1 | tee "$val_output"
        VAL_OUTPUT_SHOWN=true
      fi
      val_exit=${PIPESTATUS[0]}
    else
      # Batch mode: spinner, or with --tail show output on screen
      if [ -n "$TAIL_LOG" ]; then
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$VAL_SCRIPT" "$impl_output" 2>&1 | tee "$val_output" | tee -a "$TAIL_LOG"
        val_exit=${PIPESTATUS[0]}
        VAL_OUTPUT_SHOWN=true
      else
        PLAN_FILE=$PLAN_FILE MAX_CHILD_LOOPS=$MAX_CHILD_LOOPS "$VAL_SCRIPT" "$impl_output" > "$val_output" 2>&1 &
        val_pid=$!
        if [ "$QUIET" = "true" ]; then wait $val_pid; else wait_pid_with_stats $val_pid "Validator auditing"; wait $val_pid; fi
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
      play_sound_fail
      $SCRIPT_EXIT 1
    fi
    
    # Log to file
    echo "" >> "$LOG_FILE"
    echo "$val_result" >> "$LOG_FILE"
    
    # Display (only if not already shown via --tail or --stream)
    if [ "$STREAM_OUTPUT" != "true" ] && [ "$QUIET" != "true" ] && [ "$VAL_OUTPUT_SHOWN" != "true" ]; then
      echo ""
      echo "$val_result"
    fi
    
    # Slack: Post validator update to thread (wrapped in code block)
    val_summary=$(extract_summary "$val_result" "VALIDATOR")
    # Remove all backticks to prevent breaking the Slack code block
    val_summary=$(printf '%s' "$val_summary" | tr -d '`')
    val_slack_msg=$(printf '🔍 *VALIDATOR*\n```\n%s\n```' "$val_summary")
    post_slack_message "$val_slack_msg" "$PIPELINE_THREAD_TS"
    post_slack_error_alert_if_needed "$val_result" "Validator"

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
    confidence_justification=""
    verdict="SKIPPED"
    status="CONTINUE"
    mode="NO_VALIDATION"
  else
    confidence=$(echo "$val_result" | sed -n 's/.*CONFIDENCE SCORE: \([0-9]*\).*/\1/p' | head -1)
    [ -z "$confidence" ] && confidence=$(echo "$val_result" | sed -n 's/.*MILESTONE CONFIDENCE SCORE: \([0-9]*\).*/\1/p' | head -1)
    confidence="${confidence:-?}"
    confidence_justification=$(echo "$val_result" | sed -n 's/.*CONFIDENCE SCORE JUSTIFICATION: \(.*\)/\1/p' | head -1)
    confidence_justification=$(echo "$confidence_justification" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$confidence_justification" ] && confidence_justification=""
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

  if [ "$OUTPUT_TYPE" = "json" ]; then
    emit_json iteration_end
  else
    if [ "$VERBOSE" = "true" ]; then
      echo ""
      echo "--- Iteration $iteration summary ---"
      echo "  Mode: $mode  ·  Duration: $(format_duration $iter_duration)  ·  Confidence: $confidence/10  ·  Verdict: $verdict"
      [ -n "$confidence_justification" ] && echo "  Confidence justification: $confidence_justification"
      echo "  Status: $status  ·  Plan: $current_plan_status"
      echo "  Elapsed: $(format_duration $total_elapsed)  ·  Avg/iter: ${avg_per_iter}s  ·  ETA: $(format_duration $eta)"
    elif [ "$QUIET" != "true" ]; then
      if [ "$SKIP_VALIDATION" = "true" ]; then
        echo "Iteration $iteration · $(format_duration_short $iter_duration) · Plan: $current_plan_status · ETA: $(format_duration_short $eta)"
      else
        echo "Iteration $iteration · $(format_duration_short $iter_duration) · Plan: $current_plan_status · Verdict: $verdict · ETA: $(format_duration_short $eta)"
      fi
    fi
  fi
  
  # Play sound: fail when validator reverted or task failed, else task-complete
  if [ "$verdict" = "FAILED" ] || [ "$verdict" = "REVERTED" ]; then
    play_sound_fail
  else
    play_sound
  fi
  play_tts_after_task "$impl_output" "$val_output" "$iteration" "$confidence" "$verdict"

  #─────────────────────────────────────────────────────────────────────────────
  # SLACK: Final summary (thread reply or standalone)
  #─────────────────────────────────────────────────────────────────────────────
  if [ "$USE_SLACK" = "true" ]; then
    summary_msg="📊 *Summary*
• Mode: $mode
• Confidence: $confidence/10${confidence_justification:+ — $confidence_justification}
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
    play_sound_plan_done
    if [ "$OUTPUT_TYPE" = "json" ]; then
      emit_json pipeline_end "all_complete" "$total_elapsed"
    else
      echo ""
      echo "--- All tasks complete ---"
      echo "  Iterations: $iteration  ·  Time: $(format_duration_short $total_elapsed)  ·  Finished $(date '+%Y-%m-%d %H:%M:%S')"
    fi

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
    current_plan_status=$(verify_plan_completion "$PLAN_FILE")
    if [ "$OUTPUT_TYPE" = "json" ]; then
      emit_json pipeline_end "stopped" "$total_elapsed"
    else
      echo ""
      echo "--- Stopped (Ctrl+C) ---"
      echo "  Iterations: $iteration/$MAX_ITERATIONS  ·  Time: $(format_duration_short $total_elapsed)  ·  Stopped $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
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

current_plan_status=$(verify_plan_completion "$PLAN_FILE")
if [ "$OUTPUT_TYPE" = "json" ]; then
  emit_json pipeline_end "max_iterations" "$total_elapsed"
else
  echo ""
  echo "--- Max iterations reached ($MAX_ITERATIONS) ---"
  echo "  Time: $(format_duration_short $total_elapsed)  ·  Log: $DISPLAY_LOG  ·  Finished $(date '+%Y-%m-%d %H:%M:%S')"
fi

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
