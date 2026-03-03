#!/bin/bash
# Wrapper: run Plan-an-go validator with cursor-agent CLI (auto model)
export PLAN_AN_GO_CLI="cursor-agent"
exec ./plan-an-go-validate.sh "$@"
