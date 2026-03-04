#!/bin/bash
#
# plan-an-go-split-run.sh — Opens a native terminal with two panes (top/bottom):
#   Top:    task watcher (plan-an-go-task-watcher.sh)
#   Bottom: forever orchestrator (plan-an-go-forever.sh)
# Uses only supported methods: Ghostty with tmux, or macOS Terminal.app with tmux.
#
# Usage:
#   npm run plan-an-go-split -- [task-watcher args] -- [forever args]
#   If no "--" is given, all arguments are passed to the forever script (bottom);
#   task watcher (top) runs with no extra args.
#
# Examples:
#   npm run plan-an-go-split
#   npm run plan-an-go-split -- --plan ./examples/count/PLAN.md
#   npm run plan-an-go-split -- --plan PLAN.md -- 100 50 --slack-enable
#

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../system/platform.sh
. "$SCRIPT_DIR/../system/platform.sh"

# Parse: [top args] -- [bottom args]
TOP_ARGS=()
BOTTOM_ARGS=()
SEEN_DELIM=false
for a in "$@"; do
  if [ "$a" = "--" ]; then
    SEEN_DELIM=true
    continue
  fi
  if [ "$SEEN_DELIM" = true ]; then
    BOTTOM_ARGS+=("$a")
  else
    TOP_ARGS+=("$a")
  fi
done

# Temp scripts under ./tmp (absolute path so tmux can run them from any cwd)
TMP_BASE="${PLAN_AN_GO_TMP:-./tmp}"
[[ "$TMP_BASE" != /* ]] && TMP_BASE="$REPO_ROOT/$TMP_BASE"
mkdir -p "$TMP_BASE"
TMP_TOP_ABS="$TMP_BASE/split-top.$$.sh"
TMP_BOT_ABS="$TMP_BASE/split-bot.$$.sh"

{
  printf 'cd %q && exec %q' "$REPO_ROOT" "$SCRIPT_DIR/plan-an-go-task-watcher.sh"
  printf ' %q' "${TOP_ARGS[@]}"
  echo
} > "$TMP_TOP_ABS"
chmod +x "$TMP_TOP_ABS"

{
  printf 'cd %q && exec %q' "$REPO_ROOT" "$SCRIPT_DIR/plan-an-go-forever.sh"
  printf ' %q' "${BOTTOM_ARGS[@]}"
  echo
} > "$TMP_BOT_ABS"
chmod +x "$TMP_BOT_ABS"

echo "Command: opening split terminals (top = task watcher, bottom = forever)."
echo "  Top args:    ${TOP_ARGS[*]:-(none)}"
echo "  Bottom args: ${BOTTOM_ARGS[*]:-(none)}"
echo ""

TMUX_CMD="tmux new-session -d 'bash $TMP_TOP_ABS' \\; split-window -v 'bash $TMP_BOT_ABS' \\; attach"

if command -v ghostty &>/dev/null; then
  ghostty -e "$TMUX_CMD"
elif [ "$(get_platform)" = "darwin" ]; then
  osascript -e "tell application \"Terminal\" to do script \"$TMUX_CMD\""
else
  echo "No supported terminal found (ghostty or macOS Terminal). Install Ghostty or run on macOS." >&2
  exit 1
fi
