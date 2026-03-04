#!/bin/bash

# plan-an-go-file-watch.sh - Monitor file/folder changes in current directory
# Displays changes with timestamps and colors
#
# Prerequisites: fswatch (see install hint per platform)
# Usage: ./plan-an-go-file-watch.sh [directory]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../system/platform.sh
. "$SCRIPT_DIR/../system/platform.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
  echo -e "${RED}Error: fswatch is not installed.${RESET}"
  echo -e "${YELLOW}Install it with: $(install_hint fswatch)${RESET}"
  exit 1
fi

# Get the current directory (where script is executed)
WATCH_DIR="${1:-$(pwd)}"

# Resolve to absolute path
WATCH_DIR=$(cd "$WATCH_DIR" && pwd)

echo -e "${BOLD}${CYAN}Watching: ${WATCH_DIR}${RESET}"
echo -e "${YELLOW}Press Ctrl+C to stop${RESET}"
echo ""

# Temp state file under ./tmp
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"
STATE_FILE=$(mktemp "$TMP_DIR/file-watch.XXXXXX")
trap "rm -f $STATE_FILE" EXIT

# Function to format timestamp
format_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Function to get relative path
get_relative_path() {
  local full_path="$1"
  local relative_path="${full_path#$WATCH_DIR/}"
  if [ "$relative_path" = "$full_path" ]; then
    echo "./$(basename "$full_path")"
  else
    echo "./$relative_path"
  fi
}

# Function to check if file was seen before
file_seen() {
  grep -Fxq "$1" "$STATE_FILE" 2>/dev/null
}

# Function to mark file as seen
mark_seen() {
  echo "$1" >> "$STATE_FILE"
}

# Function to remove file from seen list
mark_unseen() {
  grep -vFx "$1" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null
  mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null
}

# Function to determine event type and format output
process_event() {
  local event_path="$1"
  local event_type="$2"

  local rel_path
  rel_path=$(get_relative_path "$event_path")

  local action=""
  local color=""

  case "$event_type" in
    Created)
      action="[Created]"
      color="$GREEN"
      ;;
    Modified)
      action="[Modified]"
      color="$YELLOW"
      ;;
    Removed)
      action="[Deleted]"
      color="$RED"
      mark_unseen "$event_path"
      ;;
    *)
      action="[Changed]"
      color="$CYAN"
      ;;
  esac

  local timestamp
  timestamp=$(format_timestamp)

  echo -e "${color}${timestamp}${RESET} - ${color}${action}${RESET} - ${BOLD}${rel_path}${RESET}"
}

# Monitor using fswatch
# -r: recursive, -m: monitor mode (continuous), -e: exclude patterns
fswatch -r -m poll_monitor \
  -e '\.git' \
  -e 'node_modules' \
  -e '\.next' \
  -e '\.turbo' \
  -e 'dist' \
  -e 'build' \
  -e '\.cache' \
  -e 'logs' \
  -e 'tmp' \
  -e '\.tsbuildinfo' \
  -e '\.DS_Store' \
  "$WATCH_DIR" | while read -r event_path; do
  if [ ! -e "$event_path" ]; then
    process_event "$event_path" "Removed"
  elif file_seen "$event_path"; then
    process_event "$event_path" "Modified"
  else
    process_event "$event_path" "Created"
    mark_seen "$event_path"
  fi
done
