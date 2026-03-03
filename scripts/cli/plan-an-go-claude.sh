#!/bin/bash
# Wrapper: run Plan-an-go implementer with Claude CLI
export PLAN_AN_GO_CLI="claude"
exec ./plan-an-go.sh "$@"
