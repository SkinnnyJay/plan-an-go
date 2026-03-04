#!/bin/bash
#
# plan-an-go-task-watcher.sh - Watch the plan file and show a live task list.
# Parses checkbox lines [x] / [ ] and M?N:?... task IDs; redraws on file change.
#
# Layout (ASCII):
#
#   +----------------------------------------------------------------------+
#   |  Plan Task Watcher                                   ./PLAN.md       |
#   +----------+-----+----------------------------------------------------+
#   |  ID      |     | Task summary (truncated to fit)                     |
#   +----------+-----+----------------------------------------------------+
#   |  M0:1    |  ✓  | Add session-scoped decision-engine lifecycle...    |
#   |  M0:2    |  ✓  | Add safe engine cache eviction/TTL...               |
#   |  M3:9b   |  ○  | Fix HybridMemoryManager.retrieve...                |
#   |  M10:7   |  ○  | Publish final confidence report...                   |
#   +----------+-----+----------------------------------------------------+
#   |  Last refresh: 2026-03-01 14:32:05                                   |
#   |  [=========================>          ] 120/129  93%                  |
#   +----------------------------------------------------------------------+
#   Watching for changes... (Ctrl+C to stop)
#
# When a task changes from incomplete to complete, it is shown checked (✓) and
# briefly highlighted in bold green on the next refresh.
# Tasks whose summary contains [IN_PROGRESS] or [IN_PROGRESS]:[AGENT_NN] are shown with a yellow ● (in progress).
# When [IN_PROGRESS]:[AGENT_01] is present, the agent id is shown in the Agent column.
# Prerequisites: fswatch (brew install fswatch) unless --once is used.
#
# Usage:
#   ./plan-an-go-task-watcher.sh [options]
#   --plan PATH      Path to plan file (default: ./PLAN.md)
#   --once           Single run, no watch
#   --width N        Terminal width for truncation (default: tput cols)
#   --max-rows N     Max task rows to show (default: LINES-8)
#   --ids-only       Show only milestone ID and checkmark (no task title)
#   --max-task-length N   Max task name length before ellipsis (default: from width)
#   --minimal             Minimal view: context around incomplete tasks only
#   --minimal-before N    In minimal mode: N completed tasks before first incomplete (default: 3)
#   --minimal-after N     In minimal mode: N completed tasks after last incomplete (default: 3)
#   --no-progress    Hide progress bar
#   --no-color       Disable color
#   --poll N         fswatch poll interval in seconds (default: 1)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../system/platform.sh
. "$SCRIPT_DIR/../system/platform.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
BLINK='\033[5m'
RESET='\033[0m'

PLAN_PATH="./PLAN.md"
ONCE=false
USE_COLOR=true
SHOW_PROGRESS=true
POLL_SECS=1
WIDTH=""
MAX_ROWS=""
IDS_ONLY=false
MAX_TASK_LENGTH=""
MINIMAL=false
MINIMAL_BEFORE=3
MINIMAL_AFTER=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      PLAN_PATH="$2"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --max-rows)
      MAX_ROWS="$2"
      shift 2
      ;;
    --ids-only)
      IDS_ONLY=true
      shift
      ;;
    --max-task-length)
      MAX_TASK_LENGTH="$2"
      shift 2
      ;;
    --minimal)
      MINIMAL=true
      shift
      ;;
    --minimal-before)
      MINIMAL_BEFORE="$2"
      shift 2
      ;;
    --minimal-after)
      MINIMAL_AFTER="$2"
      shift 2
      ;;
    --no-progress)
      SHOW_PROGRESS=false
      shift
      ;;
    --no-color)
      USE_COLOR=false
      shift
      ;;
    --poll)
      POLL_SECS="$2"
      shift 2
      ;;
    -h|--help)
      head -50 "$0" | grep -E '^#|^\s+--|^\s+\./'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" 1>&2
      exit 1
      ;;
  esac
done

if [[ -z "$WIDTH" ]]; then
  WIDTH=$(tput cols 2>/dev/null) || WIDTH=80
fi

if [[ ! -f "$PLAN_PATH" ]]; then
  echo "Error: Plan file not found: $PLAN_PATH" 1>&2
  exit 1
fi

# Ensure minimal context is non-negative integers
MINIMAL_BEFORE=$(( MINIMAL_BEFORE + 0 ))
MINIMAL_AFTER=$(( MINIMAL_AFTER + 0 ))
[[ "$MINIMAL_BEFORE" -lt 0 ]] && MINIMAL_BEFORE=0
[[ "$MINIMAL_AFTER" -lt 0 ]] && MINIMAL_AFTER=0

TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"

PLAN_ABS=$(cd "$(dirname "$PLAN_PATH")" && pwd)/$(basename "$PLAN_PATH")
STATE_DIR=$(mktemp -d "$TMP_DIR/task-watcher.XXXXXX")
PREV_COMPLETED="${STATE_DIR}/prev_completed.txt"
CURRENT_TASKS="${STATE_DIR}/current_tasks.txt"
FIRST_RUN="${STATE_DIR}/first_run.flag"
trap "rm -rf $STATE_DIR" EXIT

touch "$PREV_COMPLETED"

# Optional: disable colors
if [[ "$USE_COLOR" != "true" ]]; then
  RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; DIM=""; BLINK=""; RESET=""
fi

format_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# Time since last modification of file (e.g. "5m ago", "1h ago")
time_since_last_change() {
  local path="$1"
  local mtime now elapsed
  if [[ -z "$path" ]] || [[ ! -f "$path" ]]; then
    echo "?"
    return
  fi
  mtime=$(stat_mtime "$path")
  if [[ -z "$mtime" ]] || [[ "$mtime" == "?" ]]; then
    echo "?"
    return
  fi
  now=$(date +%s)
  elapsed=$(( now - mtime ))
  if [[ $elapsed -lt 60 ]]; then
    echo "${elapsed}s ago"
  elif [[ $elapsed -lt 3600 ]]; then
    echo "$(( elapsed / 60 ))m ago"
  elif [[ $elapsed -lt 86400 ]]; then
    echo "$(( elapsed / 3600 ))h ago"
  else
    echo "$(( elapsed / 86400 ))d ago"
  fi
}

# Parse plan: output lines "DONE\tID\tDESCRIPTION\tAGENT" (DONE=0 incomplete, 1 complete, 2 in-progress).
# When in-progress with [IN_PROGRESS]:[AGENT_NN], AGENT is set; completed may have [AGENT_NN] (who completed it).
parse_tasks() {
  awk '
    BEGIN { OFS="\t" }
    /\[x\] *- *M[0-9]+:/ {
      if (match($0, /M[0-9]+:[0-9A-Za-z.]+/)) {
        id = substr($0, RSTART, RLENGTH)
        rest = substr($0, RSTART + RLENGTH)
        sub(/^[-\t ]+/, "", rest)
        gsub(/\t/, " ", rest)
        agent = ""
        if (match(rest, /\[AGENT_[0-9]+\]/)) {
          agent = substr(rest, RSTART + 1, RLENGTH - 2)
          sub(/ *\[AGENT_[0-9]+\] *$/, "", rest)
        }
        print "1", id, rest, agent
      }
      next
    }
    /\[[ ]+\] *- *M[0-9]+:/ {
      if (match($0, /M[0-9]+:[0-9A-Za-z.]+/)) {
        id = substr($0, RSTART, RLENGTH)
        rest = substr($0, RSTART + RLENGTH)
        sub(/^[-\t ]+/, "", rest)
        gsub(/\t/, " ", rest)
        agent = ""
        if (match(rest, /\[IN_PROGRESS\]:\[AGENT_[0-9]+\]/)) {
          status = "2"
          agent = substr(rest, RSTART + 14, RLENGTH - 15)
          sub(/ \[IN_PROGRESS\]:\[AGENT_[0-9]+\]/, "", rest)
        } else if (index(rest, "[IN_PROGRESS]") > 0) {
          status = "2"
          sub(/ \[IN_PROGRESS\]/, "", rest)
        } else {
          status = "0"
        }
        print status, id, rest, agent
      }
      next
    }
  ' "$PLAN_PATH" 2>/dev/null || true
}

# Truncate string to byte length (avoid breaking UTF-8 mid-char for simple case we trim to width)
truncate_desc() {
  local max="$1"
  local s="$2"
  if [[ ${#s} -le "$max" ]]; then
    echo "$s"
  else
    echo "${s:0:$((max-3))}..."
  fi
}

# Draw progress bar: completed total width -> [=====>   ] n/total pct
progress_bar() {
  local completed="$1"
  local total="$2"
  local w="${3:-40}"
  local pct=0
  local filled=0
  if [[ "$total" -gt 0 ]]; then
    pct=$(( completed * 100 / total ))
    filled=$(( w * completed / total ))
    [[ "$filled" -gt "$w" ]] && filled="$w"
  fi
  local empty=$(( w - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}="; done
  for (( i=0; i<empty; i++ )); do bar="${bar} "; done
  echo "[${bar}] ${completed}/${total}  ${pct}%"
}

# Column widths (ID, check, description fills rest)
ID_COL=10
CHECK_COL=5
DESC_COL=$(( WIDTH - ID_COL - CHECK_COL - 8 ))
[[ "$DESC_COL" -lt 10 ]] && DESC_COL=40
if [[ -n "$MAX_TASK_LENGTH" ]]; then
  DESC_COL=$(( MAX_TASK_LENGTH + 0 ))
  [[ "$DESC_COL" -lt 5 ]] && DESC_COL=40
fi

# Write minimal window (Y before first incomplete, all incomplete, X after last) to stdout
minimal_window() {
  local before="$1"
  local after="$2"
  awk -F'\t' -v before="$before" -v after="$after" '
    { lines[NR]=$0; done[NR]=$1 }
    $1!=1 { if (first==0) first=NR; last=NR }
    END {
      if (first==0) { start=1; end=NR }
      else {
        start = first - before; if (start<1) start=1
        end = last + after; if (end>NR) end=NR
      }
      for (i=start; i<=end; i++) print lines[i]
    }
  ' "$CURRENT_TASKS" 2>/dev/null || cat "$CURRENT_TASKS"
}

redraw() {
  set +e
  parse_tasks > "$CURRENT_TASKS" || true
  local total
  total=$(wc -l < "$CURRENT_TASKS" 2>/dev/null) || total=0
  total=$(( total + 0 ))
  local completed=0
  [[ -s "$CURRENT_TASKS" ]] && completed=$(awk -F'\t' '$1==1 {c++} END {print c+0}' "$CURRENT_TASKS")

  # Build set of previously completed IDs; newly completed = in curr but not in prev
  awk -F'\t' '$1==1 {print $2}' "$CURRENT_TASKS" > "${STATE_DIR}/curr_completed.txt" 2>/dev/null || true
  sort -u "${STATE_DIR}/curr_completed.txt" 2>/dev/null > "${STATE_DIR}/curr_sorted.txt" || true
  sort -u "$PREV_COMPLETED" 2>/dev/null > "${STATE_DIR}/prev_sorted.txt" || true
  # Only highlight newly completed after first run (so prev is from last redraw)
  if [[ -f "$FIRST_RUN" ]]; then
    comm -23 "${STATE_DIR}/curr_sorted.txt" "${STATE_DIR}/prev_sorted.txt" 2>/dev/null > "${STATE_DIR}/newly_completed.txt" || true
  else
    touch "${STATE_DIR}/newly_completed.txt"
  fi
  cp "${STATE_DIR}/curr_completed.txt" "$PREV_COMPLETED" 2>/dev/null || true
  touch "$FIRST_RUN" 2>/dev/null || true

  ( tput clear 2>/dev/null || clear ) || true
  tput cup 0 0 2>/dev/null || true

  local task_file="$CURRENT_TASKS"
  if [[ "$MINIMAL" == "true" ]]; then
    minimal_window "$MINIMAL_BEFORE" "$MINIMAL_AFTER" > "${STATE_DIR}/minimal_tasks.txt" 2>/dev/null || true
    task_file="${STATE_DIR}/minimal_tasks.txt"
  fi

  if [[ "$MINIMAL" == "true" ]]; then
    echo -e "${BOLD}${CYAN}Plan Task Watcher (minimal)${RESET}${DIM}                  $(basename "$PLAN_PATH")${RESET}"
    sep=""
    for (( i=0; i<DESC_COL; i++ )); do sep="${sep}-"; done
    echo -e "${DIM}+----------+-----+${sep}+${RESET}"
    printf "${DIM}%-10s | %-3s | %-${DESC_COL}s${RESET}\n" "ID" "" "Task summary"
    echo -e "${DIM}+----------+-----+${sep}+${RESET}"
  elif [[ "$IDS_ONLY" == "true" ]]; then
    echo -e "${BOLD}${CYAN}Plan Task Watcher (IDs only)${RESET}${DIM}                    $(basename "$PLAN_PATH")${RESET}"
    echo -e "${DIM}+----------+-----+${RESET}"
    printf "${DIM}%-10s | %-3s${RESET}\n" "ID" ""
    echo -e "${DIM}+----------+-----+${RESET}"
  else
    sep=""
    for (( i=0; i<DESC_COL; i++ )); do sep="${sep}-"; done
    echo -e "${BOLD}${CYAN}Plan Task Watcher${RESET}${DIM}                                    $(basename "$PLAN_PATH")${RESET}"
    echo -e "${DIM}+----------+-----+${sep}+${RESET}"
    printf "${DIM}%-10s | %-3s | %-${DESC_COL}s${RESET}\n" "ID" "" "Task summary"
    echo -e "${DIM}+----------+-----+${sep}+${RESET}"
  fi

  local max_rows=30
  [[ -n "$LINES" ]] && max_rows=$(( LINES - 8 ))
  [[ -n "$MAX_ROWS" ]] && max_rows=$(( MAX_ROWS + 0 ))
  [[ "$max_rows" -lt 1 ]] && max_rows=30
  local row=0
  while IFS= read -r line && [[ $row -lt $max_rows ]]; do
    done_flag=$(echo "$line" | cut -f1)
    id=$(echo "$line" | cut -f2)
    desc=$(echo "$line" | cut -f3)
    agent=$(echo "$line" | cut -f4)
    # Append agent id to description for in-progress tasks
    if [[ "$done_flag" == "2" ]] && [[ -n "$agent" ]]; then
      desc="$desc [$agent]"
    fi
    desc=$(truncate_desc "$DESC_COL" "$desc")
    desc="${desc//%/%%}"
    check="○"
    style="${RESET}"
    if [[ "$done_flag" == "1" ]]; then
      check="✓"
      if [[ -f "${STATE_DIR}/newly_completed.txt" ]] && [[ -s "${STATE_DIR}/newly_completed.txt" ]] && grep -Fxq "$id" "${STATE_DIR}/newly_completed.txt" 2>/dev/null; then
        style="${GREEN}${BOLD}"
      else
        style="${GREEN}"
      fi
    elif [[ "$done_flag" == "2" ]]; then
      check="●"
      style="${YELLOW}"
    else
      style="${DIM}"
    fi
    if [[ "$IDS_ONLY" == "true" ]] && [[ "$MINIMAL" != "true" ]]; then
      printf "%-10s | ${style}%-3s${RESET}\n" "$id" "$check"
    else
      printf "%-10s | ${style}%-3s${RESET} | %-${DESC_COL}s\n" "$id" "$check" "$desc"
    fi
    row=$(( row + 1 ))
  done < "$task_file"

  completed=$(awk -F'\t' 'BEGIN{c=0} $1==1{c++} END{print c+0}' "$CURRENT_TASKS" 2>/dev/null) || completed=0
  local not_complete=$(( total - completed ))
  [[ "$not_complete" -lt 0 ]] && not_complete=0

  if [[ "$IDS_ONLY" == "true" ]]; then
    echo -e "${DIM}+----------+-----+${RESET}"
  else
    echo -e "${DIM}+----------+-----+${sep}+${RESET}"
  fi
  if [[ "$MINIMAL" == "true" ]]; then
    echo -e "${DIM}Complete: ${completed}   Not complete: ${not_complete}${RESET}"
    echo -e "${DIM}Last file change: $(time_since_last_change "$PLAN_ABS")${RESET}"
  fi
  echo -e "${DIM}Last refresh: $(format_timestamp)${RESET}"
  if [[ "$SHOW_PROGRESS" == "true" ]]; then
    local bar_w=$(( WIDTH - 20 ))
    [[ "$bar_w" -lt 20 ]] && bar_w=40
    echo -e "${BOLD}$(progress_bar "$completed" "$total" "$bar_w")${RESET}"
  fi
  bot_sep=""
  for (( i=0; i<WIDTH-2; i++ )); do bot_sep="${bot_sep}-"; done
  echo -e "${DIM}+${bot_sep}+${RESET}"
  if [[ "$ONCE" != "true" ]]; then
    echo -e "${YELLOW}Watching for changes... (Ctrl+C to stop)${RESET}"
  fi
  set -e
}

export LINES
LINES=$(tput lines 2>/dev/null) || LINES=24

if [[ "$ONCE" == "true" ]]; then
  redraw
  exit 0
fi

if ! command -v fswatch &>/dev/null; then
  echo -e "${RED}Error: fswatch is not installed.${RESET}"
  echo -e "${YELLOW}Install with: $(install_hint fswatch)${RESET}"
  echo "Or run with: --once"
  exit 1
fi

redraw
while true; do
  fswatch -1 -r -m poll_monitor -l "$POLL_SECS" "$PLAN_ABS" &>/dev/null || true
  sleep 0.2
  redraw
done
