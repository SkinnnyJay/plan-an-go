#!/bin/bash
# plan-work-section.sh — Helpers for <work>...</work> block(s) in PLAN.md
# A plan may have multiple <work>...</work> chunks; all are considered the work section.
#
# Usage:
#   bounds:    ./plan-work-section.sh bounds <plan_file>
#              Prints one "start end" per block (line numbers between each <work> and </work>).
#              If non-compliant, uses fallback heuristics (first **M*:0** + code-fence skip), one line.
#   extract:   ./plan-work-section.sh extract <plan_file>
#              Prints lines from all <work>...</work> blocks concatenated; if non-compliant, whole file.
#   compliant: ./plan-work-section.sh compliant <plan_file>
#              Exit 0 if at least one block has at least one task line inside; else exit 1.
# Exit: 0 on success (compliant: 0 = compliant, 1 = not); 1 if file missing/unreadable or usage error.

set -e

SUBCOMMAND="${1:-}"
PLAN_FILE="${2:-}"

if [ -z "$SUBCOMMAND" ] || [ -z "$PLAN_FILE" ]; then
  echo "Usage: $0 bounds|extract|compliant <plan_file>" >&2
  exit 1
fi

if [ ! -f "$PLAN_FILE" ] || [ ! -r "$PLAN_FILE" ]; then
  exit 1
fi

case "$SUBCOMMAND" in
  compliant)
    # Compliant = at least one <work>...</work> block contains at least one task line
    if ! grep -q '<work>' "$PLAN_FILE" 2>/dev/null || ! grep -q '</work>' "$PLAN_FILE" 2>/dev/null; then
      exit 1
    fi
    awk '
      /<work>/     { in_block = 1; block_has = 0 }
      /<\/work>/   { if (block_has) compliant = 1; in_block = 0 }
      in_block && /^\[ \] - M[0-9]+:|^\[  \] - M[0-9]+:|^\[x\] - M[0-9]+:/ { block_has = 1 }
      END          { exit (compliant ? 0 : 1) }
    ' "$PLAN_FILE"
    exit $?
    ;;
  bounds)
    # Output one "start end" per <work>...</work> block. When no <work>: fallback to one range (heuristics).
    last_line=$(wc -l <"$PLAN_FILE" | tr -d ' ')
    [ -z "$last_line" ] && last_line=1
    range=$(awk -v last="$last_line" '
      /^```/     { in_code = 1 - in_code; next }
      in_code    { next }
      /<work>/   { s = NR + 1; next }
      /<\/work>/ { if (s) { e = NR - 1; print s, (e >= s ? e : s); s = 0; found = 1 } }
      /^\*\*M[0-9]+:0/ { candidate = NR }
      /^\[ \] - M[0-9]+:|^\[  \] - M[0-9]+:|^\[x\] - M[0-9]+:/ {
        if (candidate && length($0) > 50 && !first_milestone) first_milestone = candidate
        candidate = 0
      }
      END { if (!found) { if (s) print s, last; else if (first_milestone) print first_milestone, last; else print "1", last } }
    ' "$PLAN_FILE")
    [ -n "$range" ] && echo "$range" || echo "1 $last_line"
    ;;
  extract)
    # Print lines from every <work>...</work> block (concatenated). If no tags, cat whole file.
    if grep -q '<work>' "$PLAN_FILE" 2>/dev/null && grep -q '</work>' "$PLAN_FILE" 2>/dev/null; then
      awk '/<work>/{f=1;next} /<\/work>/{f=0;next} f' "$PLAN_FILE"
    else
      cat "$PLAN_FILE"
    fi
    ;;
  *)
    echo "Usage: $0 bounds|extract|compliant <plan_file>" >&2
    exit 1
    ;;
esac
