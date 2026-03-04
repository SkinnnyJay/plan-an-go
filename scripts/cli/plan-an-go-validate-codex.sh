#!/bin/bash
# Wrapper: run Plan-an-go validator with Codex CLI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLAN_AN_GO_CLI="codex"
exec "$SCRIPT_DIR/plan-an-go-validate.sh" "$@"
