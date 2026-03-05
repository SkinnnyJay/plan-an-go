#!/bin/bash
# plan-an-go-onboard.sh — Onboarding umbrella: menu to route to the right script, optional review of key env vars.
# Usage: ./plan-an-go-onboard.sh
#   Run via: plan-an-go onboard   or   npm run plan-an-go:onboard
#   Asks what you want to do, optionally lets you review/edit key variables (from .env or defaults), then runs the chosen command.

set -e
set -o pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$CLI_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env from repo root so we show/source current values
if [ -f "$REPO_ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$REPO_ROOT/.env"
  set +a
fi

# Resolve operating root (same as entry script)
if [ -n "$PLAN_AN_GO_ROOT" ]; then
  PLAN_AN_GO_ROOT="$(cd "$PLAN_AN_GO_ROOT" && pwd)"
else
  PLAN_AN_GO_ROOT="$REPO_ROOT"
fi
export PLAN_AN_GO_ROOT

# Defaults for key variables (when unset in .env)
default_plan_file="${PLAN_FILE:-PLAN.md}"
default_tmp="${PLAN_AN_GO_TMP:-./tmp}"
default_cli="${PLAN_AN_GO_CLI:-claude}"
default_use_slack="${PLAN_AN_GO_USE_SLACK:-${USE_SLACK:-false}}"
default_claude_model="${PLAN_AN_GO_CLAUDE_MODEL:-claude-sonnet-4-20250514}"
default_codex_model="${PLAN_AN_GO_CODEX_MODEL:-codex-20250301}"

# Prompt for a value: show [current], Enter keeps it, else use typed value. Optional mask for secrets.
prompt_var() {
  local label="$1"
  local current="$2"
  local mask="${3:-0}"
  local display="$current"
  if [ "$mask" = "1" ] && [ -n "$current" ]; then
    display="***"
  fi
  read -r -p "$label [$display]: " val
  if [ -z "$val" ]; then
    echo "$current"
  else
    echo "$val"
  fi
}

# Review/set key variables and export for this session (no .env write unless user does it).
review_vars() {
  echo ""
  echo "--- Key variables (Enter = keep current / default, or type new value) ---"

  PLAN_FILE=$(prompt_var "PLAN_FILE (plan path)" "$default_plan_file")
  export PLAN_FILE
  default_plan_file="$PLAN_FILE"

  PLAN_AN_GO_TMP=$(prompt_var "PLAN_AN_GO_TMP (logs/temp dir)" "$default_tmp")
  export PLAN_AN_GO_TMP
  default_tmp="$PLAN_AN_GO_TMP"

  PLAN_AN_GO_ROOT=$(prompt_var "PLAN_AN_GO_ROOT (operating root)" "$PLAN_AN_GO_ROOT")
  PLAN_AN_GO_ROOT="$(cd "$PLAN_AN_GO_ROOT" && pwd)"
  export PLAN_AN_GO_ROOT

  PLAN_AN_GO_CLI=$(prompt_var "PLAN_AN_GO_CLI (claude|cline|copilot|codex|cursor-agent|droid|gemini|goose|kiro|opencode)" "$default_cli")
  export PLAN_AN_GO_CLI
  default_cli="$PLAN_AN_GO_CLI"

  PLAN_AN_GO_CLAUDE_MODEL=$(prompt_var "PLAN_AN_GO_CLAUDE_MODEL" "$default_claude_model")
  export PLAN_AN_GO_CLAUDE_MODEL
  default_claude_model="$PLAN_AN_GO_CLAUDE_MODEL"

  PLAN_AN_GO_CODEX_MODEL=$(prompt_var "PLAN_AN_GO_CODEX_MODEL" "$default_codex_model")
  export PLAN_AN_GO_CODEX_MODEL
  default_codex_model="$PLAN_AN_GO_CODEX_MODEL"

  PLAN_AN_GO_USE_SLACK=$(prompt_var "PLAN_AN_GO_USE_SLACK (true|false)" "$default_use_slack")
  export PLAN_AN_GO_USE_SLACK
  default_use_slack="$PLAN_AN_GO_USE_SLACK"

  echo "API keys (PLAN_AN_GO_ANTHROPIC_API_KEY, PLAN_AN_GO_OPENAI_API_KEY): set in $REPO_ROOT/.env if needed; not shown here."
  echo "--- Done. These apply for this session only; edit .env to persist. ---"
  echo ""
}

show_menu() {
  echo ""
  echo "What do you want to do?"
  echo "  1) System setup       — Install CLIs, authenticate, verify"
  echo "  2) Run one cycle      — One implementer run (plan-an-go run)"
  echo "  3) Run pipeline loop   — Implement → validate until done (forever)"
  echo "  4) Generate PRD       — Create PRD from a prompt (prd)"
  echo "  5) Generate plan     — Create PLAN.md from prompt or PRD (planner)"
  echo "  6) Full wizard        — PRD → review → update → validate → write → launch"
  echo "  7) Validate output    — Validate a saved implementer output file"
  echo "  8) Task watcher       — Live view of plan tasks (requires fswatch)"
  echo "  9) Reset plan         — Mark all tasks incomplete ([x] → [ ])"
  echo "  v) Review/set variables — Show and edit key env vars for this session"
  echo "  h) Help               — Show plan-an-go help"
  echo "  q) Quit"
  echo ""
}

run_choice() {
  local choice="$1"
  case "$choice" in
    1) (cd "$REPO_ROOT" && "$SCRIPT_DIR/plan-an-go" setup) ;;
    2) "$SCRIPT_DIR/plan-an-go" run ;;
    3) "$SCRIPT_DIR/plan-an-go" forever ;;
    4) "$SCRIPT_DIR/plan-an-go" prd ;;
    5) "$SCRIPT_DIR/plan-an-go" planner ;;
    6) "$SCRIPT_DIR/plan-an-go" wizard ;;
    7)
      read -r -p "Path to implementer output file: " f
      [ -n "$f" ] && "$SCRIPT_DIR/plan-an-go" validate "$f"
      ;;
    8) "$SCRIPT_DIR/plan-an-go" task-watcher ;;
    9) "$SCRIPT_DIR/plan-an-go" reset ;;
    v|V) review_vars ;;
    h|H) "$SCRIPT_DIR/plan-an-go" help ;;
    q|Q) echo "Bye."; exit 0 ;;
    *) echo "Unknown option. Try again." >&2 ;;
  esac
}

# --- main ---
echo "=== plan-an-go onboarding ==="
echo "Root: $PLAN_AN_GO_ROOT"
echo ""

read -r -p "Review or set key variables before choosing an action? (y/N): " do_review
case "$do_review" in
  y|Y) review_vars ;;
  *) ;;
esac

while true; do
  show_menu
  read -r -p "Choice (1-9, v, h, q): " choice
  run_choice "$choice"
done
