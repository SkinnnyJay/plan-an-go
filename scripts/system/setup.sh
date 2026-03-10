#!/bin/bash
# setup.sh — One-shot system setup: link plan-an-go CLI, install CLIs, authenticate, verify.
# Usage: ./setup.sh [options] [install options...]
#   --skip-link       do not run install-plan-an-go.sh (do not link plan-an-go to PATH)
#   --skip-install    do not run install-clis.sh
#   --skip-auth       do not run auth-cli.sh
#   --skip-verify     do not run verify.sh
#   --force           pass --force to verify (warnings only, exit 0)
#   Remaining args are passed to install-clis (e.g. 'all' or 'claude codex').

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKIP_LINK=false
SKIP_INSTALL=false
SKIP_AUTH=false
SKIP_VERIFY=false
VERIFY_FORCE=false
INSTALL_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-link) SKIP_LINK=true ;;
    --skip-install) SKIP_INSTALL=true ;;
    --skip-auth) SKIP_AUTH=true ;;
    --skip-verify) SKIP_VERIFY=true ;;
    --force) VERIFY_FORCE=true ;;
    *) INSTALL_ARGS+=("$1") ;;
  esac
  shift
done

echo "=== plan-an-go system setup ==="

if [ "$SKIP_LINK" = false ]; then
  echo "--- Step 1: Install plan-an-go CLI (npm link) ---"
  "$SCRIPT_DIR/install-plan-an-go.sh"
else
  echo "--- Step 1: Install plan-an-go CLI (skipped) ---"
fi

if [ "$SKIP_INSTALL" = false ]; then
  echo "--- Step 2: Install CLIs ---"
  if [ ${#INSTALL_ARGS[@]} -eq 0 ]; then
    "$SCRIPT_DIR/install-clis.sh"
  else
    "$SCRIPT_DIR/install-clis.sh" "${INSTALL_ARGS[@]}"
  fi
else
  echo "--- Step 2: Install CLIs (skipped) ---"
fi

if [ "$SKIP_AUTH" = false ]; then
  echo "--- Step 3: Authenticate CLIs ---"
  "$SCRIPT_DIR/auth-cli.sh"
else
  echo "--- Step 3: Authenticate CLIs (skipped) ---"
fi

if [ "$SKIP_VERIFY" = false ]; then
  echo "--- Step 4: Verify ---"
  if [ "$VERIFY_FORCE" = true ]; then
    "$SCRIPT_DIR/verify.sh" --force
  else
    "$SCRIPT_DIR/verify.sh"
  fi
else
  echo "--- Step 4: Verify (skipped) ---"
fi

echo "=== setup complete ==="
