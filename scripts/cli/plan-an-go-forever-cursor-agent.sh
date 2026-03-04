#!/bin/bash
# Wrapper: run Plan-an-go pipeline with cursor-agent CLI (auto model)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLAN_AN_GO_CLI="cursor-agent"
exec "$SCRIPT_DIR/plan-an-go-forever.sh" "$@"
