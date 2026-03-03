#!/bin/bash
# install-clis.sh — Install CLIs required for plan-an-go (claude, codex, cursor-agent, jq, fswatch).
# Usage: ./install-clis.sh [claude] [codex] [cursor-agent] [jq] [fswatch]   # install only these
#        ./install-clis.sh                                                  # interactive: y/n for each
#        ./install-clis.sh all                                              # install all that can be installed

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# CLIs that we can install automatically
INSTALLABLE_CLIS="claude codex jq fswatch"
# cursor-agent is typically provided by Cursor IDE; we only check for it
CHECK_ONLY_CLIS="cursor-agent"

is_installed() {
  command -v "$1" &>/dev/null
}

install_claude() {
  if is_installed claude; then
    echo "  claude already installed."
    return 0
  fi
  echo "  Installing claude (Anthropic Claude Code CLI)..."
  if [[ "$(uname -s)" == "Darwin" ]]; then
    curl -fsSL https://claude.ai/install.sh | bash || {
      echo "  Fallback: npm install -g @anthropic-ai/claude-code"
      npm install -g @anthropic-ai/claude-code
    }
  else
    npm install -g @anthropic-ai/claude-code
  fi
  if ! is_installed claude; then
    echo "  WARNING: claude may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  claude installed."
}

install_codex() {
  if is_installed codex; then
    echo "  codex already installed."
    return 0
  fi
  echo "  Installing codex (OpenAI Codex CLI)..."
  if command -v brew &>/dev/null; then
    brew install --cask codex 2>/dev/null || npm install -g @openai/codex
  else
    npm install -g @openai/codex
  fi
  if ! is_installed codex; then
    echo "  WARNING: codex may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  codex installed."
}

install_jq() {
  if is_installed jq; then
    echo "  jq already installed."
    return 0
  fi
  echo "  Installing jq..."
  if command -v brew &>/dev/null; then
    brew install jq
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  else
    echo "  Please install jq manually: https://jqlang.github.io/jq/download/"
    return 1
  fi
  echo "  jq installed."
}

install_fswatch() {
  if is_installed fswatch; then
    echo "  fswatch already installed."
    return 0
  fi
  echo "  Installing fswatch (optional, for file watching)..."
  if command -v brew &>/dev/null; then
    brew install fswatch
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y fswatch
  else
    echo "  Please install fswatch manually if you need file-watch features."
    return 1
  fi
  echo "  fswatch installed."
}

check_cursor_agent() {
  if is_installed cursor-agent; then
    echo "  cursor-agent is in PATH."
    return 0
  fi
  echo "  cursor-agent not found. Install Cursor IDE; the agent is usually available when Cursor is installed."
  return 1
}

run_install() {
  local name="$1"
  case "$name" in
    claude)         install_claude ;;
    codex)          install_codex ;;
    jq)             install_jq ;;
    fswatch)        install_fswatch ;;
    cursor-agent)   check_cursor_agent ;;
    *)              echo "  Unknown CLI: $name"; return 1 ;;
  esac
}

# Parse args: "all" or list of names
WANT_ALL=false
WANT_CLIS=()
for arg in "$@"; do
  if [ "$arg" = "all" ]; then
    WANT_ALL=true
  else
    WANT_CLIS+=("$arg")
  fi
done

# If no args, interactive
if [ ${#WANT_CLIS[@]} -eq 0 ] && [ "$WANT_ALL" != "true" ]; then
  echo "Install plan-an-go CLIs. Choose which to install (y/n)."
  for c in $INSTALLABLE_CLIS $CHECK_ONLY_CLIS; do
    if [ "$c" = "cursor-agent" ]; then
      echo -n "  Check only (no install): cursor-agent [y/n]? "
    else
      echo -n "  Install $c [y/n]? "
    fi
    read -r ans
    case "$ans" in
      y|Y|yes) WANT_CLIS+=("$c") ;;
    esac
  done
fi

# Default to all installable + cursor-agent check if "all"
if [ "$WANT_ALL" = "true" ]; then
  WANT_CLIS=(claude codex jq fswatch cursor-agent)
fi

# If still empty, show usage and exit
if [ ${#WANT_CLIS[@]} -eq 0 ]; then
  echo "Usage: $0 [all | claude codex jq fswatch cursor-agent]"
  echo "  No CLIs selected. Run with 'all' or list names, or run without args for interactive."
  exit 0
fi

echo "Installing/checking: ${WANT_CLIS[*]}"
FAILED=0
for c in "${WANT_CLIS[@]}"; do
  run_install "$c" || FAILED=$((FAILED + 1))
done

if [ $FAILED -gt 0 ]; then
  echo "One or more installs failed or were skipped. Fix PATH or install manually if needed."
  exit 1
fi
echo "Done."
exit 0
