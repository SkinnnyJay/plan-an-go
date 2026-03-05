#!/bin/bash
# plan-an-go-doc-metadata.sh — Emit plan-an-go document metadata block for PLAN.md / PRD.md
# Usage: ./plan-an-go-doc-metadata.sh <created_by> <generated_cli>
# Output: HTML comment wrapping a plan_meta_data fenced block so previews do not render it.
# Used by plan-an-go-planner.sh, plan-an-go-prd.sh, plan-an-go-prd-from-plan.sh to prepend to generated files.

set -e
CREATED_BY="${1:-unknown}"
GENERATED_CLI="${2:-unknown}"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '<!-- 
```plan_meta_data
{"created_by":"%s","created_at":"%s","last_updated":"%s","generated_cli":"%s"}
```
-->

' \
  "$CREATED_BY" "$NOW" "$NOW" "$GENERATED_CLI"
