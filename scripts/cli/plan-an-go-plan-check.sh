#!/bin/bash
# plan-an-go-plan-check.sh — Plan file health check for Plan-an-go
# Usage: ./plan-an-go-plan-check.sh [--strict] [plan_file]
#
# 1. Checks for plan file (default: PLAN.md)
# 2. If --strict: exit 1 when plan is not <work>-compliant
# 3. Reads and parses it (uses <work> block when present)
# 4. Counts milestones, tasks, subtasks
# 5. Counts complete vs incomplete
# 6. Reports formatting issues
#
# Exit: 0 if plan exists and no critical format issues; 1 if missing/empty, critical issues, or --strict and non-compliant.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRICT_WORK=false
if [ "${1:-}" = "--strict" ]; then
  STRICT_WORK=true
  shift
fi
PLAN_FILE="${1:-${PLAN_FILE:-PLAN.md}}"
# Resolve to absolute path if relative (relative to cwd)
if [ "${PLAN_FILE#/}" = "$PLAN_FILE" ]; then
  PLAN_FILE="$(pwd)/$PLAN_FILE"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

#═══════════════════════════════════════════════════════════════════════════════
# 1. Check for plan file
#═══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}${CYAN}Plan-an-go Plan Check: $PLAN_FILE${RESET}"
echo ""

if [ ! -f "$PLAN_FILE" ]; then
  echo -e "${RED}ERROR: Plan file not found: $PLAN_FILE${RESET}"
  echo "Usage: $0 [--strict] [plan_file]   (default: PLAN.md)"
  exit 1
fi

if [ ! -s "$PLAN_FILE" ]; then
  echo -e "${RED}ERROR: Plan file is empty: $PLAN_FILE${RESET}"
  exit 1
fi

echo -e "${GREEN}1. Plan file found ($(wc -c <"$PLAN_FILE" | tr -d ' ') bytes)${RESET}"
if ! grep -q 'plan_meta_data' "$PLAN_FILE" 2>/dev/null && ! grep -q '```json metadata' "$PLAN_FILE" 2>/dev/null; then
  echo -e "${YELLOW}   WARN: No plan-an-go metadata block (<!-- ... plan_meta_data ... -->). Consider regenerating with the planner for traceability.${RESET}"
fi
echo ""

# <work> compliance: compliant = has <work>...</work> with at least one task line inside
WORK_EXTRACT="$SCRIPT_DIR/scripts/plan-work-section.sh"
WORK_COMPLIANT=false
if [ -f "$WORK_EXTRACT" ]; then
  if bash "$WORK_EXTRACT" compliant "$PLAN_FILE" 2>/dev/null; then
    WORK_COMPLIANT=true
  fi
fi
if [ "$WORK_COMPLIANT" = "false" ]; then
  echo -e "${YELLOW}⚠️  Plan is not <work>-compliant (missing <work>...</work> or no task lines inside).${RESET}"
  echo -e "   Counts may include prompt/example text. Wrap milestones and tasks in <work>...</work>. See README."
  echo ""
  if [ "$STRICT_WORK" = "true" ]; then
    echo -e "${RED}ERROR: Refusing to continue with --strict.${RESET}"
    exit 1
  fi
fi

# When <work>...</work> exists, count/validate only that block so prose elsewhere is ignored
CHECK_FILE="$PLAN_FILE"
if [ -f "$WORK_EXTRACT" ] && grep -q '<work>' "$PLAN_FILE" 2>/dev/null && grep -q '</work>' "$PLAN_FILE" 2>/dev/null; then
  CHECK_FILE=$(mktemp)
  trap 'rm -f "$CHECK_FILE"' EXIT
  bash "$WORK_EXTRACT" extract "$PLAN_FILE" >"$CHECK_FILE"
fi

#═══════════════════════════════════════════════════════════════════════════════
# 2. Counts, 3. Completion: parse milestones, tasks, subtasks, complete/incomplete
#═══════════════════════════════════════════════════════════════════════════════
# Milestone = **M<n>:0 - Title** (section header)
# Task = line starting with [ ] or [x] then " - M<n>:<id>-" (id may have .<sub>)
# Subtask = task whose id contains a dot (e.g. M6:1.1, M7:2.1)
# Complete = [x] or [X]; Incomplete = [ ] (with any amount of space)

total_milestones=0
total_tasks=0
total_subtasks=0
complete_tasks=0
incomplete_tasks=0

# Count milestone headers: **M<num>:0 - ... (POSIX grep)
total_milestones=$(grep -cE '^\*\*M[0-9]+:0[[:space:]]+-' "$CHECK_FILE" 2>/dev/null) || total_milestones=0

# Task lines: must contain M<n>:<id> and checkbox [ ] or [x] at start of line (POSIX)
task_lines=$(grep -E 'M[0-9]+:[0-9]+' "$CHECK_FILE" 2>/dev/null | grep -E '^[[:space:]]*\[([[:space:]]*\]|[xX]\])' || true)
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if [[ "$line" =~ ^[[:space:]]*\[[[:space:]]*\] ]]; then
    incomplete_tasks=$((incomplete_tasks + 1))
    total_tasks=$((total_tasks + 1))
    [[ "$line" =~ M[0-9]+:[0-9]+\.[0-9]+ ]] && total_subtasks=$((total_subtasks + 1))
  elif [[ "$line" =~ ^[[:space:]]*\[[xX]\] ]]; then
    complete_tasks=$((complete_tasks + 1))
    total_tasks=$((total_tasks + 1))
    [[ "$line" =~ M[0-9]+:[0-9]+\.[0-9]+ ]] && total_subtasks=$((total_subtasks + 1))
  fi
done <<<"$task_lines"

echo -e "${BOLD}2. Counts${RESET}"
echo "   Milestones:  $total_milestones"
echo "   Tasks:       $total_tasks (including subtasks)"
echo "   Subtasks:    $total_subtasks (tasks with dotted IDs, e.g. M6:1.1)"
echo ""

echo -e "${BOLD}3. Completion${RESET}"
echo "   Complete:    $complete_tasks"
echo "   Incomplete:  $incomplete_tasks"
if [ "$total_tasks" -gt 0 ]; then
  pct=$((complete_tasks * 100 / total_tasks))
  echo "   Progress:    ${pct}%"
fi
echo ""

#═══════════════════════════════════════════════════════════════════════════════
# 5. Formatting issues
#═══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}4. Formatting checks${RESET}"
format_issues=0

# Check: checkbox should be [ ] or [x], not [x ] or [ x] etc.
bad_checkbox=$(grep -nE '^[[:space:]]*\[[^[:space:]xX]\].*M[0-9]+:' "$CHECK_FILE" 2>/dev/null || true)
if [ -n "$bad_checkbox" ]; then
  echo -e "   ${YELLOW}Non-standard checkbox (use [ ] or [x]):${RESET}"
  echo "$bad_checkbox" | while read -r l; do echo "     $l"; done
  format_issues=$((format_issues + 1))
fi

# Check: task line should have " - M<n>:<id>-" (dash after id before description)
malformed_task=$(grep -nE '^[[:space:]]*\[([[:space:]]*\]|[xX])\][[:space:]]*-[[:space:]]+M[0-9]+:[0-9]+[^-[:space:].]' "$CHECK_FILE" 2>/dev/null || true)
if [ -n "$malformed_task" ]; then
  malformed_task=$(grep -nE '^[[:space:]]*\[([[:space:]]*\]|[xX])\][[:space:]]*-[[:space:]]+M[0-9]+:[0-9]+[a-zA-Z]' "$CHECK_FILE" 2>/dev/null || true)
  if [ -n "$malformed_task" ]; then
    echo -e "   ${YELLOW}Task ID with unexpected character (expected M<n>:<id>- or M<n>:<id>.<sub>-):${RESET}"
    echo "$malformed_task" | while read -r l; do echo "     $l"; done
    format_issues=$((format_issues + 1))
  fi
fi

# Check: milestone headers should be **M<n>:0 - Title**
bad_milestone=$(grep -nE '^\*\*M[0-9]+:[1-9]' "$CHECK_FILE" 2>/dev/null || true)
if [ -n "$bad_milestone" ]; then
  echo -e "   ${YELLOW}Milestone header with non-zero id (expected M<n>:0):${RESET}"
  echo "$bad_milestone" | while read -r l; do echo "     $l"; done
  format_issues=$((format_issues + 1))
fi

# Check: checkbox lines that look like tasks but have no M<n>: id
no_id=$(grep -nE '^[[:space:]]*\[([[:space:]]*\]|[xX])\][[:space:]]*-[[:space:]]+' "$CHECK_FILE" 2>/dev/null | while read -r l; do
  if ! echo "$l" | grep -qE 'M[0-9]+:'; then echo "$l"; fi
done)
if [ -n "$no_id" ]; then
  echo -e "   ${YELLOW}Checkbox line without M<n>: task ID:${RESET}"
  echo "$no_id" | while read -r l; do echo "     $l"; done
  format_issues=$((format_issues + 1))
fi

if [ "$format_issues" -eq 0 ]; then
  echo -e "   ${GREEN}No formatting issues detected.${RESET}"
else
  echo -e "   ${YELLOW}Total formatting issues: $format_issues${RESET}"
fi
echo ""

#═══════════════════════════════════════════════════════════════════════════════
# Summary
#═══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}Summary${RESET}"
echo "   File:        $PLAN_FILE"
echo "   Milestones:  $total_milestones"
echo "   Tasks:       $total_tasks (complete: $complete_tasks, incomplete: $incomplete_tasks)"
echo "   Subtasks:    $total_subtasks"
echo "   Format:      $([ "$format_issues" -eq 0 ] && echo "OK" || echo "${format_issues} issue(s)")"
echo ""

# Exit 1 only if plan missing/empty or critical: no milestones or no tasks at all
if [ "$total_milestones" -eq 0 ] || [ "$total_tasks" -eq 0 ]; then
  echo -e "${RED}CRITICAL: No milestones or no tasks found. Check plan format.${RESET}"
  exit 1
fi
exit 0
