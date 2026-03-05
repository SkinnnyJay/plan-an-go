#!/bin/bash
# Wrapper: run Plan-an-go implementer with Gemini CLI
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLAN_AN_GO_CLI="gemini"
exec "$SCRIPT_DIR/plan-an-go.sh" "$@"
