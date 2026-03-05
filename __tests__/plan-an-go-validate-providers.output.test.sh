#!/usr/bin/env bash
# Output test: plan-an-go-validate-{claude,codex,cursor-agent}.sh forward to plan-an-go-validate.sh.
# With no args all show same error (implementer output required). Writes only to ./tmp/.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI_DIR="$REPO_ROOT/scripts/cli"
OUT="./tmp/plan-an-go-validate-providers.output.out"
VERBOSE=""
[ " ${*:-}" = " --verbose" ] && VERBOSE=1

cd "$REPO_ROOT"
mkdir -p ./tmp

want="Implementer output file required"
run_provider() {
  local name="$1"
  local script="$CLI_DIR/plan-an-go-validate-$name.sh"
  if [ ! -f "$script" ]; then
    echo "Missing script: $script"; exit 1
  fi
  : > "$OUT"
  "$script" >> "$OUT" 2>&1 || true
  if ! grep -q "$want" "$OUT"; then
    echo "Provider $name: expected '$want' in output"
    cat "$OUT"
    exit 1
  fi
  if [ -n "$VERBOSE" ]; then echo "  OK: $name"; fi
}

run_provider "claude"
run_provider "codex"
run_provider "cursor-agent"

exit 0
