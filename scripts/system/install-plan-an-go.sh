#!/bin/bash
# install-plan-an-go.sh — Register plan-an-go and pag on PATH via npm link.
# Usage: ./install-plan-an-go.sh
# Run from repo root or scripts/system; uses directory containing scripts/ as repo root.
# Idempotent: npm link overwrites the global link; safe to run multiple times.

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v npm &>/dev/null; then
  echo "ERROR: npm not found. Install Node.js/npm first." >&2
  exit 1
fi

if command -v plan-an-go &>/dev/null || command -v pag &>/dev/null; then
  echo "  plan-an-go or pag already on PATH; linking again to ensure they point to this repo..."
fi

echo "  Registering plan-an-go and pag (npm link)..."
(cd "$REPO_ROOT" && npm link) || {
  echo "ERROR: npm link failed. Ensure you have write access to npm global prefix." >&2
  exit 1
}

if ! command -v plan-an-go &>/dev/null && ! command -v pag &>/dev/null; then
  echo "WARNING: linked but not on PATH. Add npm global bin to PATH (e.g. export PATH=\"\$(npm config get prefix)/bin:\$PATH\")." >&2
  exit 1
fi
echo "  plan-an-go and pag registered. Run 'plan-an-go help' or 'pag help' from any directory."
