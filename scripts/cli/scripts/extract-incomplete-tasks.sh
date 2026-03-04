#!/usr/bin/env bash
# extract-incomplete-tasks.sh — Write plan with only header + incomplete tasks to reduce token usage
# Usage: ./extract-incomplete-tasks.sh <plan_file> <output_file> [agent_id]
#   When agent_id is set (e.g. AGENT_01), only incomplete lines containing [IN_PROGRESS]:[agent_id] are included.
# Exit: 0 on success, 1 if plan missing/empty or write fails.

set -e

PLAN_FILE="${1:?Usage: $0 <plan_file> <output_file> [agent_id]}"
OUT_FILE="${2:?Usage: $0 <plan_file> <output_file> [agent_id]}"
AGENT_ID="${3:-${PLAN_AN_GO_AGENT_ID:-}}"

if [ ! -f "$PLAN_FILE" ] || [ ! -s "$PLAN_FILE" ]; then
  exit 1
fi

: > "$OUT_FILE"

# Milestone header: **M<n>:0 - Title**
# Incomplete task (bracket style): [ ] - or [  ] - then M<n>:<id>-
# Incomplete task (template style): - [ ] **
in_task_section=0
last_milestone=""

while IFS= read -r line || [ -n "$line" ]; do
  # Detect milestone header
  if [[ "$line" =~ ^\*\*M[0-9]+:0[[:space:]]+- ]]; then
    in_task_section=1
    last_milestone="$line"
    echo "$line" >> "$OUT_FILE"
    continue
  fi

  # Before any milestone, keep header lines (summary, instructions, etc.)
  if [ "$in_task_section" -eq 0 ]; then
    echo "$line" >> "$OUT_FILE"
    continue
  fi

  # In task section: print only incomplete task lines
  # When AGENT_ID is set, only include lines that contain [IN_PROGRESS]:[AGENT_ID]
  # Bracket style: [ ] - M or [  ] - M (one or two spaces in bracket)
  if [[ "$line" =~ ^[[:space:]]*\[[[:space:]]{1,2}\][[:space:]]*-[[:space:]]*M[0-9]+:[0-9]+ ]]; then
    if [ -z "$AGENT_ID" ]; then
      echo "$line" >> "$OUT_FILE"
    elif [[ "$line" == *"[IN_PROGRESS]:[${AGENT_ID}]"* ]]; then
      echo "$line" >> "$OUT_FILE"
    fi
    continue
  fi
  # Template style: - [ ] **
  if [[ "$line" =~ ^-[[:space:]]*\[[[:space:]]\][[:space:]]*\*\* ]]; then
    if [ -z "$AGENT_ID" ]; then
      echo "$line" >> "$OUT_FILE"
    elif [[ "$line" == *"[IN_PROGRESS]:[${AGENT_ID}]"* ]]; then
      echo "$line" >> "$OUT_FILE"
    fi
    continue
  fi

  # Keep blank lines between tasks in task section; drop completed task lines
  if [ -z "$line" ] && [ -n "$last_milestone" ]; then
    echo "$line" >> "$OUT_FILE"
  fi
done < "$PLAN_FILE"
