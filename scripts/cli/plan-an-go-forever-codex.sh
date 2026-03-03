#!/bin/bash
# Wrapper: run Plan-an-go pipeline with Codex CLI
export PLAN_AN_GO_CLI="codex"
exec ./plan-an-go-forever.sh "$@"
