#!/bin/bash
# Wrapper: run Plan-an-go validator with Claude CLI
export PLAN_AN_GO_CLI="claude"
exec ./plan-an-go-validate.sh "$@"
