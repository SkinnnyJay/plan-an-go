#!/bin/bash
# platform.sh — Portable platform detection and helpers for plan-an-go scripts.
# Source this file; do not execute. Provides: get_platform, stat_mtime, install_hint.
# Usage in other scripts: SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" then . "$SCRIPT_DIR/platform.sh" (or . "$SCRIPT_DIR/system/platform.sh")

# Returns: darwin | linux | windows
get_platform() {
  local u
  u="$(uname -s 2>/dev/null)"
  case "$u" in
    Darwin)           echo darwin ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *)                echo linux ;;
  esac
}

# Portable file mtime as epoch (or "?" on error). Use in task-watcher and similar.
stat_mtime() {
  local path="$1"
  local mtime
  if [[ -z "$path" ]] || [[ ! -f "$path" ]]; then
    echo "?"
    return
  fi
  case "$(get_platform)" in
    darwin) mtime=$(stat -f %m "$path" 2>/dev/null) ;;
    *)      mtime=$(stat -c %Y "$path" 2>/dev/null) ;;
  esac
  if [[ -z "$mtime" ]]; then
    echo "?"
  else
    echo "$mtime"
  fi
}

# Echo install hint for a given tool (jq or fswatch). Used by file-watch and tts-summary.
install_hint() {
  local tool="$1"
  case "$(get_platform)" in
    darwin)
      case "$tool" in
        jq)      echo "brew install jq" ;;
        fswatch) echo "brew install fswatch" ;;
        *)       echo "install $tool manually" ;;
      esac
      ;;
    linux)
      case "$tool" in
        jq)      echo "sudo apt-get install -y jq   # or: brew install jq" ;;
        fswatch) echo "sudo apt-get install -y fswatch   # or: brew install fswatch" ;;
        *)       echo "install $tool manually" ;;
      esac
      ;;
    windows)
      case "$tool" in
        jq)      echo "winget install jqlang.jq   # or: choco install jq" ;;
        fswatch) echo "choco install fswatch   # or install manually" ;;
        *)       echo "install $tool manually" ;;
      esac
      ;;
    *)
      echo "install $tool manually"
      ;;
  esac
}
