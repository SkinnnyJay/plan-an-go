#!/bin/bash
# Wrapper: run Plan-an-go pipeline with Claude CLI
export PLAN_AN_GO_CLI="claude"
exec ./plan-an-go-forever.sh "$@"
