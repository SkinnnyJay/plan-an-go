#!/bin/bash
# Wrapper: run Plan-an-go implementer with cursor-agent CLI (auto model)
export PLAN_AN_GO_CLI="cursor-agent"
exec ./plan-an-go.sh "$@"
