#!/bin/bash
# extract-incomplete-tasks.sh — Write plan with only header + incomplete tasks to reduce token usage
# Usage: ./extract-incomplete-tasks.sh <plan_file> <output_file> [agent_id]
#   When agent_id is set (e.g. AGENT_01), only incomplete lines containing [IN_PROGRESS]:[agent_id] are included.
# Exit: 0 on success, 1 if plan missing/empty or write fails.

set -e
set -o pipefail

PLAN_FILE="${1:?Usage: $0 <plan_file> <output_file> [agent_id]}"
OUT_FILE="${2:?Usage: $0 <plan_file> <output_file> [agent_id]}"
AGENT_ID="${3:-${PLAN_AN_GO_AGENT_ID:-}}"

if [ ! -f "$PLAN_FILE" ] || [ ! -s "$PLAN_FILE" ]; then
  exit 1
fi

: > "$OUT_FILE"

# When <work>...</work> exists, only output task content from inside any such block (plan may have multiple).
# Otherwise (backward compat) use first milestone to start the task section.
# Milestone: **M<n>:0 - Title**; Incomplete task: [ ] - M<n>:<id>- or - [ ] **
in_work=0
in_task_section=0
after_work=0
last_milestone=""

while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^\<work\> ]]; then
    echo "$line" >> "$OUT_FILE"
    in_work=1
    after_work=0
    continue
  fi
  if [[ "$line" =~ ^\</work\> ]]; then
    echo "$line" >> "$OUT_FILE"
    in_work=0
    after_work=1
    continue
  fi

  # Before <work> or before first milestone (no <work>): keep header
  if [ "$in_work" -eq 0 ] && [ "$in_task_section" -eq 0 ]; then
    echo "$line" >> "$OUT_FILE"
    continue
  fi

  # After </work>: keep postamble (success criteria, etc.)
  if [ "$after_work" -eq 1 ]; then
    echo "$line" >> "$OUT_FILE"
    continue
  fi

  # Inside <work> or after first milestone (no <work>): output only milestones and incomplete tasks
  if [[ "$line" =~ ^\*\*M[0-9]+:0[[:space:]]+- ]]; then
    in_task_section=1
    last_milestone="$line"
    echo "$line" >> "$OUT_FILE"
    continue
  fi
  if [[ "$line" =~ ^[[:space:]]*\[[[:space:]]{1,2}\][[:space:]]*-[[:space:]]*M[0-9]+:[0-9]+ ]]; then
    if [ -z "$AGENT_ID" ]; then
      echo "$line" >> "$OUT_FILE"
    elif [[ "$line" == *"[IN_PROGRESS]:[${AGENT_ID}]"* ]]; then
      echo "$line" >> "$OUT_FILE"
    fi
    continue
  fi
  if [[ "$line" =~ ^-[[:space:]]*\[[[:space:]]\][[:space:]]*\*\* ]]; then
    if [ -z "$AGENT_ID" ]; then
      echo "$line" >> "$OUT_FILE"
    elif [[ "$line" == *"[IN_PROGRESS]:[${AGENT_ID}]"* ]]; then
      echo "$line" >> "$OUT_FILE"
    fi
    continue
  fi
  if [ -z "$line" ] && [ -n "$last_milestone" ]; then
    echo "$line" >> "$OUT_FILE"
  fi
done < "$PLAN_FILE"
