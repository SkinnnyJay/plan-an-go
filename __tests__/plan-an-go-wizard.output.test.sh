#!/usr/bin/env bash
# Output test: plan-an-go-wizard.sh and wizard step scripts (args, missing state, help).
# No real CLI invocation; uses --skip and state file. Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WIZARD="$REPO_ROOT/scripts/cli/plan-an-go-wizard.sh"
WIZARD_STEPS="$REPO_ROOT/scripts/cli/wizard"
ARTIFACTS="$SCRIPT_DIR/artifacts"
OUT="./tmp/plan-an-go-wizard.output.out"
STATE="$REPO_ROOT/tmp/wizard-state"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

# 1) Wizard with --skip 6: runs steps 1-5 only; step 1 needs prompt (interactive or args)
#    Without args step 1 would prompt; use high --skip to test orchestrator only
> "$OUT"
if [ -f "$STATE" ]; then rm -f "$STATE"; fi
PLAN_AN_GO_ROOT="$REPO_ROOT" WIZARD_STATE_FILE="$STATE" "$WIZARD" --skip 6 2>> "$OUT" | head -5 >> "$OUT" 2>&1 || true
# With skip 6 we run steps 1..5. Step 1 prompts for input (no args). So we'd hang or get timeout.
# Instead: test --skip 1 with state so steps 2-6 run; step 2 prompts "revision notes", step 6 "Launch?"
# Pipe empty revision then "n" for launch.
> "$OUT"
mkdir -p "$(dirname "$STATE")"
echo "WIZARD_PRD_PATH=$ARTIFACTS/PRD.md" > "$STATE"
printf '\nn\n' | PLAN_AN_GO_ROOT="$REPO_ROOT" WIZARD_STATE_FILE="$STATE" "$WIZARD" --skip 1 >> "$OUT" 2>&1
# Step 2 reads revision (empty), step 3 skips (no revisions), step 4 validates, step 5 OK, step 6 asks then "Skip launch"
grep -q "\[wizard\]" "$OUT" || { echo "Expected [wizard] in output"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: wizard --skip 1 with state"; fi

# 2) Wizard step 4 (validate-prd): no state, no --prd-path → ERROR
> "$OUT"
rm -f "$STATE"
if "$WIZARD_STEPS/wizard-step-4-validate-prd.sh" >> "$OUT" 2>&1; then
  echo "Expected non-zero exit when PRD path not set"; exit 1
fi
grep -q "ERROR: PRD path not set" "$OUT" || { echo "Expected PRD path not set"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: step 4 no path"; fi

# 3) Wizard step 4: --prd-path nonexistent → ERROR
> "$OUT"
if "$WIZARD_STEPS/wizard-step-4-validate-prd.sh" --prd-path ./tmp/nonexistent-prd.md >> "$OUT" 2>&1; then
  echo "Expected non-zero exit for missing PRD file"; exit 1
fi
grep -q "ERROR: PRD not found\|not found" "$OUT" || { echo "Expected PRD not found"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: step 4 nonexistent file"; fi

# 4) Wizard step 4: --prd-path artifact PRD → exit 0
> "$OUT"
if ! "$WIZARD_STEPS/wizard-step-4-validate-prd.sh" --prd-path "$ARTIFACTS/PRD.md" >> "$OUT" 2>&1; then
  echo "Step 4 should pass for valid PRD"; cat "$OUT"; exit 1
fi
grep -q "Step 4 OK\|Validate PRD" "$OUT" || true
if [ -n "$VERBOSE" ]; then echo "  OK: step 4 valid PRD"; fi

# 5) Wizard step 1: --prompt empty with --prd-out → exit 1 (prompt required)
#    Pipe empty line for prompt read, then a line for CLI read so we reach "Prompt required" check
> "$OUT"
if printf '\nclaude\n' | "$WIZARD_STEPS/wizard-step-1-prd.sh" --prd-out ./tmp/out.md --prompt "" >> "$OUT" 2>&1; then
  echo "Expected non-zero exit when prompt empty"; exit 1
fi
grep -q "ERROR: Prompt required\|Prompt required" "$OUT" || { echo "Expected prompt required"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: step 1 prompt required"; fi

# 6) Wizard step 5: no state, no --prd-path → ERROR
> "$OUT"
rm -f "$STATE"
if "$WIZARD_STEPS/wizard-step-5-write-file.sh" >> "$OUT" 2>&1; then
  echo "Expected non-zero exit when PRD path not set"; exit 1
fi
grep -q "ERROR: PRD path not set" "$OUT" || { echo "Expected PRD path not set"; cat "$OUT"; exit 1; }
if [ -n "$VERBOSE" ]; then echo "  OK: step 5 no path"; fi

exit 0
