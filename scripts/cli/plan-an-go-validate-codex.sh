#!/bin/bash
# Wrapper: run Plan-an-go validator with Codex CLI
export PLAN_AN_GO_CLI="codex"
exec ./plan-an-go-validate.sh "$@"
