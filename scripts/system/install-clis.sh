#!/bin/bash
# install-clis.sh — Install CLIs required for plan-an-go (claude, codex, cursor-agent, jq, fswatch).
# Dispatches to install-clis-<platform>.sh (darwin, linux, windows). See scripts/system/platform.sh.
# Usage: ./install-clis.sh [claude] [codex] [cursor-agent] [jq] [fswatch]   # install only these
#        ./install-clis.sh                                                  # interactive: y/n for each
#        ./install-clis.sh all                                              # install all that can be installed

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Shared helper (used by platform scripts when sourced)
is_installed() {
  command -v "$1" &>/dev/null
}

# Platform detection and platform-specific install functions
# shellcheck source=scripts/system/platform.sh
. "$SCRIPT_DIR/platform.sh"
PLATFORM=$(get_platform)
INSTALL_SCRIPT="$SCRIPT_DIR/install-clis-$PLATFORM.sh"
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "ERROR: No install script for platform '$PLATFORM' ($INSTALL_SCRIPT). Supported: darwin, linux, windows." >&2
  exit 1
fi
# shellcheck source=scripts/system/install-clis-darwin.sh
# shellcheck source=scripts/system/install-clis-linux.sh
# shellcheck source=scripts/system/install-clis-windows.sh
. "$INSTALL_SCRIPT"

# CLIs that we can install automatically
INSTALLABLE_CLIS="claude codex jq fswatch"
# cursor-agent is typically provided by Cursor IDE; we only check for it
CHECK_ONLY_CLIS="cursor-agent"

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
  echo "Install plan-an-go CLIs (platform: $PLATFORM). Choose which to install (y/n)."
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

echo "Installing/checking: ${WANT_CLIS[*]} (platform: $PLATFORM)"
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
