#!/bin/bash
# verify.sh — Verify system setup: CLIs installed, env keys set, ready for plan-an-go.
# Usage: ./verify.sh           # exit 1 on missing CLIs or keys (warnings for optional)
#        ./verify.sh --force    # print warnings but always exit 0

set -e
set -o pipefail
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
    if [ -n "${PLAN_AN_GO_ANTHROPIC_API_KEY:-}" ] || [ -n "${ANTHROPIC_API_KEY:-}" ]; then
      echo "OK: Anthropic API key is set (PLAN_AN_GO_ANTHROPIC_API_KEY or ANTHROPIC_API_KEY)"
    elif command -v claude &>/dev/null && claude auth status &>/dev/null; then
      echo "OK: claude auth status passed"
    else
      echo "ERROR: claude auth required. Set PLAN_AN_GO_ANTHROPIC_API_KEY in .env or run scripts/system/auth-cli.sh claude"
      ERRORS=$((ERRORS + 1))
    fi
    ;;
  cline)
    echo "OK: cline auth is via cline auth or API keys (see docs.cline.bot)"
    ;;
  codex)
    if [ -n "${PLAN_AN_GO_OPENAI_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ]; then
      echo "OK: OpenAI API key is set (PLAN_AN_GO_OPENAI_API_KEY or OPENAI_API_KEY)"
    elif command -v codex &>/dev/null; then
      if codex auth status &>/dev/null 2>&1 || true; then
        echo "OK: codex auth assumed (no status command or already logged in)"
      else
        echo "WARN: codex login may be needed. Set PLAN_AN_GO_OPENAI_API_KEY in .env or run scripts/system/auth-cli.sh codex"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    ;;
  copilot)
    if [ -n "${COPILOT_GITHUB_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
      echo "OK: Copilot/GitHub token is set (COPILOT_GITHUB_TOKEN or GITHUB_TOKEN)"
    elif command -v copilot &>/dev/null; then
      echo "WARN: Copilot token not set. Set COPILOT_GITHUB_TOKEN in .env or run scripts/system/auth-cli.sh copilot"
      WARNINGS=$((WARNINGS + 1))
    else
      echo "ERROR: copilot CLI not found or token not set"
      ERRORS=$((ERRORS + 1))
    fi
    ;;
  cursor-agent)
    echo "OK: cursor-agent auth is via Cursor IDE"
    ;;
  gemini)
    if [ -n "${PLAN_AN_GO_GEMINI_API_KEY:-}" ] || [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
      echo "OK: Gemini API key is set (PLAN_AN_GO_GEMINI_API_KEY, GEMINI_API_KEY, or GOOGLE_API_KEY)"
    elif command -v gemini &>/dev/null; then
      echo "WARN: Gemini key not set. Set PLAN_AN_GO_GEMINI_API_KEY in .env or run scripts/system/auth-cli.sh gemini"
      WARNINGS=$((WARNINGS + 1))
    else
      echo "ERROR: gemini CLI not found or key not set"
      ERRORS=$((ERRORS + 1))
    fi
    ;;
  droid)
    echo "OK: droid auth is via Factory API key (see docs.factory.ai)"
    ;;
  goose)
    echo "OK: goose auth is via ~/.config/goose (configure provider in profiles)"
    ;;
  kiro)
    echo "OK: kiro auth is via kiro auth or Kiro CLI config (see kiro.dev/docs/cli)"
    ;;
  opencode)
    echo "OK: opencode auth is via opencode auth login (~/.local/share/opencode/auth.json)"
    ;;
  *)
    echo "WARN: unknown CLI '$CLI_BIN'; cannot verify auth"
    WARNINGS=$((WARNINGS + 1))
    ;;
esac

# 4) Optional CLIs (warn only)
for cmd in cline codex copilot cursor-agent droid gemini goose kiro opencode jq; do
  if [ "$cmd" = "$CLI_BIN" ]; then continue; fi
  if ! command -v "$cmd" &>/dev/null; then
    echo "WARN: optional '$cmd' not in PATH (install with scripts/system/install-clis.sh if needed)"
    WARNINGS=$((WARNINGS + 1))
  fi
done

# 5) Slack (optional)
USE_SLACK="${PLAN_AN_GO_USE_SLACK:-${USE_SLACK:-false}}"
if [ "$USE_SLACK" = "true" ]; then
  if [ -z "${PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN:-}" ] && [ -z "${PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN:-}" ]; then
    echo "WARN: PLAN_AN_GO_USE_SLACK=true but Slack tokens not set in .env"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "OK: Slack tokens appear set"
  fi
  if ! command -v jq &>/dev/null; then
    echo "WARN: jq recommended for Slack updates (scripts/system/install-clis.sh jq)"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# 6) Plan file (optional; often created later)
PLAN_FILE="${PLAN_FILE:-PLAN.md}"
if [ ! -f "$REPO_ROOT/$PLAN_FILE" ]; then
  echo "INFO: $PLAN_FILE not found (create it when starting a plan)"
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
