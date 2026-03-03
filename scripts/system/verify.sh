#!/bin/bash
# verify.sh — Verify system setup: CLIs installed, env keys set, ready for plan-an-go.
# Usage: ./verify.sh           # exit 1 on missing CLIs or keys (warnings for optional)
#        ./verify.sh --force    # print warnings but always exit 0

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_LOCAL="$REPO_ROOT/.env.local"

FORCE=false
for arg in "$@"; do
  [ "$arg" = "--force" ] && FORCE=true
done

# Load env to check keys
load_env() {
  for f in "$ENV_FILE" "$ENV_LOCAL"; do
    [ -f "$f" ] && set -a && . "$f" 2>/dev/null; set +a
  done
}
load_env

ERRORS=0
WARNINGS=0

echo "=== plan-an-go system verify ==="

# 1) .env presence
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env not found. Copy .env.sample to .env and set variables."
  ERRORS=$((ERRORS + 1))
else
  echo "OK: .env exists"
fi

# 2) Required CLI (from PLAN_AN_GO_CLI)
CLI_BIN="${PLAN_AN_GO_CLI:-claude}"
if command -v "$CLI_BIN" &>/dev/null; then
  echo "OK: selected CLI '$CLI_BIN' is in PATH"
else
  echo "ERROR: selected CLI '$CLI_BIN' not found. Set PLAN_AN_GO_CLI or run scripts/system/install-clis.sh"
  ERRORS=$((ERRORS + 1))
fi

# 3) Auth for selected CLI (key or logged in)
case "$CLI_BIN" in
  claude)
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
      echo "OK: ANTHROPIC_API_KEY is set"
    elif command -v claude &>/dev/null && claude auth status &>/dev/null; then
      echo "OK: claude auth status passed"
    else
      echo "ERROR: claude auth required. Set ANTHROPIC_API_KEY in .env or run scripts/system/auth-cli.sh claude"
      ERRORS=$((ERRORS + 1))
    fi
    ;;
  codex)
    if [ -n "${OPENAI_API_KEY:-}" ]; then
      echo "OK: OPENAI_API_KEY is set"
    elif command -v codex &>/dev/null; then
      if codex auth status &>/dev/null 2>&1 || true; then
        echo "OK: codex auth assumed (no status command or already logged in)"
      else
        echo "WARN: codex login may be needed. Set OPENAI_API_KEY in .env or run scripts/system/auth-cli.sh codex"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    ;;
  cursor-agent)
    echo "OK: cursor-agent auth is via Cursor IDE"
    ;;
  *)
    echo "WARN: unknown CLI '$CLI_BIN'; cannot verify auth"
    WARNINGS=$((WARNINGS + 1))
    ;;
esac

# 4) Optional CLIs (warn only)
for cmd in codex cursor-agent jq; do
  if [ "$cmd" = "$CLI_BIN" ]; then continue; fi
  if ! command -v "$cmd" &>/dev/null; then
    echo "WARN: optional '$cmd' not in PATH (install with scripts/system/install-clis.sh if needed)"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# 5) Slack (optional)
USE_SLACK="${USE_SLACK:-false}"
if [ "$USE_SLACK" = "true" ]; then
  if [ -z "${PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN:-}" ]; then
    echo "WARN: USE_SLACK=true but Slack tokens not set in .env"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "OK: Slack tokens appear set"
  fi
  if ! command -v jq &>/dev/null; then
    echo "WARN: jq recommended for Slack updates (scripts/system/install-clis.sh jq)"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# 6) PRD file (optional; often created later)
PRD_FILE="${PRD_FILE:-PRD.md}"
if [ ! -f "$REPO_ROOT/$PRD_FILE" ]; then
  echo "INFO: $PRD_FILE not found (create it when starting a plan)"
fi

echo "---"
if [ $ERRORS -gt 0 ]; then
  echo "VERDICT: FAILED ($ERRORS error(s), $WARNINGS warning(s))"
  [ "$FORCE" = true ] && exit 0 || exit 1
fi
if [ $WARNINGS -gt 0 ]; then
  echo "VERDICT: OK with $WARNINGS warning(s)"
else
  echo "VERDICT: OK"
fi
exit 0
