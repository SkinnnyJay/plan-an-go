#!/bin/bash
# Wrapper: run Plan-an-go validator with Droid CLI (Factory.ai)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PLAN_AN_GO_CLI="droid"
exec "$SCRIPT_DIR/plan-an-go-validate.sh" "$@"
