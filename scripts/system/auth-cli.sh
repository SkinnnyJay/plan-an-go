#!/bin/bash
# auth-cli.sh — Authenticate CLIs used by plan-an-go (web login or use API keys from .env).
# Usage: ./auth-cli.sh [claude] [cline] [copilot] [codex] [cursor-agent] [droid] [gemini] [goose] [kiro] [opencode]   # auth only these
#        ./auth-cli.sh                                   # interactive: y/n for each
#        ./auth-cli.sh all                               # auth all that support login
#        ./auth-cli.sh --logout [claude] [codex] ...     # log out from selected or all

set -e
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_LOCAL="$REPO_ROOT/.env.local"

# Load env so we can check for API keys (don't overwrite existing exports)
load_env() {
  for f in "$ENV_FILE" "$ENV_LOCAL"; do
    [ -f "$f" ] && set -a && . "$f" 2>/dev/null; set +a
  done
}
load_env
# Prefer prefixed keys so CLIs see the key under standard names
ANTHROPIC_API_KEY="${PLAN_AN_GO_ANTHROPIC_API_KEY:-$ANTHROPIC_API_KEY}"
OPENAI_API_KEY="${PLAN_AN_GO_OPENAI_API_KEY:-$OPENAI_API_KEY}"
GEMINI_API_KEY="${PLAN_AN_GO_GEMINI_API_KEY:-${GEMINI_API_KEY:-$GOOGLE_API_KEY}}"
export ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY

LOGOUT_MODE=false
WANT_ALL=false
WANT_CLIS=()

for arg in "$@"; do
  case "$arg" in
    --logout) LOGOUT_MODE=true ;;
    all)      WANT_ALL=true; WANT_CLIS=(claude codex gemini) ;;
    claude|cline|copilot|codex|cursor-agent|droid|gemini|goose|kiro|opencode) WANT_CLIS+=("$arg") ;;
  esac
done

# If not logout and no CLIs chosen, interactive
if [ "$LOGOUT_MODE" = false ] && [ ${#WANT_CLIS[@]} -eq 0 ]; then
  echo "Authenticate plan-an-go CLIs. Web login or API keys from .env (PLAN_AN_GO_* or standard names)."
  for c in claude cline copilot codex droid gemini goose kiro opencode; do
    echo -n "  Authenticate $c [y/n]? "
    read -r ans
    case "$ans" in
      y|Y|yes) WANT_CLIS+=("$c") ;;
    esac
  done
fi

# Logout: expand to both if "all" was implied
if [ "$LOGOUT_MODE" = true ]; then
  if [ ${#WANT_CLIS[@]} -eq 0 ]; then
    WANT_CLIS=(claude codex)
  fi
  for c in "${WANT_CLIS[@]}"; do
    case "$c" in
      claude)
        if command -v claude &>/dev/null; then
          echo "Logging out from claude..."
          claude auth logout 2>/dev/null || true
        fi
        ;;
      codex)
        if command -v codex &>/dev/null; then
          echo "Logging out from codex..."
          codex logout 2>/dev/null || codex auth logout 2>/dev/null || true
        fi
        ;;
      cline) echo "cline: clear API keys or run cline logout if supported." ;;
      copilot) echo "copilot: run 'copilot auth logout' or clear GitHub token if supported." ;;
      cursor-agent) echo "cursor-agent: no separate logout (Cursor IDE session)." ;;
      droid) echo "droid: clear Factory API key from env to stop using." ;;
      gemini) echo "gemini: clear PLAN_AN_GO_GEMINI_API_KEY or GEMINI_API_KEY from .env to stop using key." ;;
      goose) echo "goose: remove or edit ~/.config/goose to log out." ;;
      kiro) echo "kiro: clear Kiro credentials or run kiro logout if supported." ;;
      opencode)
        if command -v opencode &>/dev/null; then
          echo "Logging out from opencode..."
          opencode auth logout 2>/dev/null || true
        fi
        ;;
      *) ;;
    esac
  done
  echo "Logout done."
  exit 0
fi

# Auth: skip if API key is set (force API key = use .env, no web)
use_api_key() {
  case "$1" in
    claude) [ -n "${ANTHROPIC_API_KEY:-}" ]; ;;
    codex)  [ -n "${OPENAI_API_KEY:-}" ]; ;;
    gemini) [ -n "${GEMINI_API_KEY:-}" ]; ;;
    copilot) [ -n "${COPILOT_GITHUB_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; ;;
    *)      false ;;
  esac
}

auth_claude() {
  if use_api_key claude; then
    echo "  claude: using API key from env (PLAN_AN_GO_ANTHROPIC_API_KEY or ANTHROPIC_API_KEY; skip web login)."
    return 0
  fi
  if ! command -v claude &>/dev/null; then
    echo "  claude not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  claude: starting web login..."
  claude auth login
}

auth_codex() {
  if use_api_key codex; then
    echo "  codex: using API key from env (PLAN_AN_GO_OPENAI_API_KEY or OPENAI_API_KEY; skip web login)."
    return 0
  fi
  if ! command -v codex &>/dev/null; then
    echo "  codex not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  codex: starting web login..."
  codex login
}

auth_cursor_agent() {
  echo "  cursor-agent: auth is managed by Cursor IDE; no separate login here."
  return 0
}

auth_gemini() {
  if use_api_key gemini; then
    echo "  gemini: using API key from env (PLAN_AN_GO_GEMINI_API_KEY, GEMINI_API_KEY, or GOOGLE_API_KEY)."
    return 0
  fi
  if ! command -v gemini &>/dev/null; then
    echo "  gemini not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  gemini: set PLAN_AN_GO_GEMINI_API_KEY or GEMINI_API_KEY in .env (from Google AI Studio)."
  return 0
}

auth_goose() {
  echo "  goose: configure providers in ~/.config/goose/profiles.yaml (no web login here)."
  return 0
}

auth_opencode() {
  if ! command -v opencode &>/dev/null; then
    echo "  opencode not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  opencode: run 'opencode auth login' to configure providers."
  return 0
}

auth_cline() {
  if ! command -v cline &>/dev/null; then
    echo "  cline not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  cline: run 'cline auth' or set API keys per Cline docs (https://docs.cline.bot)."
  return 0
}

auth_copilot() {
  if use_api_key copilot; then
    echo "  copilot: using token from env (COPILOT_GITHUB_TOKEN or GITHUB_TOKEN)."
    return 0
  fi
  if ! command -v copilot &>/dev/null; then
    echo "  copilot not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  copilot: run 'copilot auth' or set COPILOT_GITHUB_TOKEN / GITHUB_TOKEN in .env."
  return 0
}

auth_droid() {
  if ! command -v droid &>/dev/null; then
    echo "  droid not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  droid: set Factory API key (see https://docs.factory.ai); run droid auth if supported."
  return 0
}

auth_kiro() {
  if ! command -v kiro &>/dev/null; then
    echo "  kiro not installed. Run scripts/system/install-clis.sh first."
    return 1
  fi
  echo "  kiro: run 'kiro auth' or set credentials per Kiro CLI docs (https://kiro.dev/docs/cli)."
  return 0
}

FAILED=0
for c in "${WANT_CLIS[@]}"; do
  case "$c" in
    claude)         auth_claude || FAILED=$((FAILED+1)) ;;
    cline)          auth_cline || FAILED=$((FAILED+1)) ;;
    codex)          auth_codex || FAILED=$((FAILED+1)) ;;
    copilot)        auth_copilot || FAILED=$((FAILED+1)) ;;
    cursor-agent)   auth_cursor_agent ;;
    droid)          auth_droid || FAILED=$((FAILED+1)) ;;
    gemini)         auth_gemini || FAILED=$((FAILED+1)) ;;
    goose)          auth_goose ;;
    kiro)           auth_kiro || FAILED=$((FAILED+1)) ;;
    opencode)       auth_opencode || FAILED=$((FAILED+1)) ;;
    *)              echo "  Unknown CLI: $c"; FAILED=$((FAILED+1)) ;;
  esac
done

if [ $FAILED -gt 0 ]; then
  echo "One or more auth steps failed."
  exit 1
fi
echo "Auth done."
exit 0
