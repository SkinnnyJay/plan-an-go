#!/bin/bash
# Wrapper: run Plan-an-go implementer with cursor-agent CLI (auto model)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLAN_AN_GO_CLI="cursor-agent"
exec "$SCRIPT_DIR/plan-an-go.sh" "$@"
