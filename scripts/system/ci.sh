#!/bin/bash
# ci.sh — Full gate for local/pre-commit: lint → format check → test.
# GitHub CI runs only lint+format (npm run check); tests require local CLIs and run here before commit.
# Usage: ./scripts/system/ci.sh   (run from repo root, or script cd's to repo root)
# For local pre-commit: npm run ci  or  make ci

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

STEP=0
fail_step() {
  echo "FAILED: $1 (exit $2)" >&2
  exit "$2"
}

run_step_npm() {
  STEP=$((STEP + 1))
  local name="$1"
  shift
  echo ""
  echo "=== Step $STEP: $name ==="
  npm run "$@" || {
    local ec=$?
    fail_step "Step $STEP: $name" "$ec"
  }
  echo "Step $STEP OK"
}

echo "plan-an-go CI (lint → format → test)"

run_step_npm "Lint" lint
run_step_npm "Format check" format
run_step_npm "Tests" test

echo ""
echo "CI passed (all steps OK)."
exit 0
