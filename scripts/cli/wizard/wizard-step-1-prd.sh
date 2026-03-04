#!/bin/bash
# wizard-step-1-prd.sh — PRD wizard: questions (path, prompt, CLI) then run plan-an-go prd
# Usage: ./wizard-step-1-prd.sh [--prd-out PATH] [--prompt "..."] [--cli claude|codex|cursor-agent] [--config PATH]
#   With no args, reads wizard-config.json and prompts; otherwise uses args and passes through to prd.
#   Writes WIZARD_PRD_PATH to state file for later steps.

set -e

WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(cd "$WIZARD_DIR/.." && pwd)"
SCRIPT_DIR="$(cd "$CLI_DIR/../.." && pwd)"
ROOT="${PLAN_AN_GO_ROOT:-$(pwd)}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
STATE_FILE="${WIZARD_STATE_FILE:-$TMP_DIR/wizard-state}"
CONFIG_FILE="${WIZARD_CONFIG:-$WIZARD_DIR/wizard-config.json}"

PRD_OUT=""
PROMPT=""
CLI=""
PREV_ARG=""

for arg in "$@"; do
  case "$arg" in
    --prd-out=*) PRD_OUT="${arg#*=}" ;;
    --prompt=*)  PROMPT="${arg#*=}" ;;
    --cli=*)     CLI="${arg#*=}" ;;
    --config=*)  CONFIG_FILE="${arg#*=}" ;;
    --prd-out)   ;;
    --prompt)    ;;
    --cli)       ;;
    --config)    ;;
    *)
      if [ "$PREV_ARG" = "--prd-out" ]; then PRD_OUT="$arg"
      elif [ "$PREV_ARG" = "--prompt" ]; then PROMPT="$arg"
      elif [ "$PREV_ARG" = "--cli" ]; then CLI="$arg"
      elif [ "$PREV_ARG" = "--config" ]; then CONFIG_FILE="$arg"
      fi
      ;;
  esac
  PREV_ARG="$arg"
done

mkdir -p "$(dirname "$STATE_FILE")"

# Resolve PRD path relative to root
resolve_path() {
  local p="$1"
  [ -z "$p" ] && return
  if [ "${p#/}" = "$p" ]; then
    echo "$ROOT/$p"
  else
    echo "$p"
  fi
}

if [ -n "$PRD_OUT" ] && [ -n "$PROMPT" ]; then
  PRD_ABS=$(resolve_path "$PRD_OUT")
  [ -z "$CLI" ] && CLI="${PLAN_AN_GO_CLI:-claude}"
  echo "[wizard] Step 1: PRD (args)" >&2
  (cd "$ROOT" && PLAN_AN_GO_CLI="$CLI" "$SCRIPT_DIR/plan-an-go" prd --out "$PRD_ABS" --prompt="$PROMPT")
  echo "WIZARD_PRD_PATH=$PRD_ABS" >> "$STATE_FILE"
  echo "WIZARD_CLI=$CLI" >> "$STATE_FILE"
  exit 0
fi

# Interactive: use config if available
if [ -f "$CONFIG_FILE" ] && command -v node >/dev/null 2>&1; then
  echo "[wizard] Step 1: PRD (config)" >&2
  PRD_DEFAULT=$(node -e "try { const c=require('$CONFIG_FILE'); const q=(c.steps&&c.steps[0]&&c.steps[0].questions)||[]; const p=q.find(x=>x.id==='prd_path'); console.log(p&&p.default?p.default:'PRD.md'); } catch(e){ console.log('PRD.md'); }")
  CLI_DEFAULT=$(node -e "try { const c=require('$CONFIG_FILE'); const q=(c.steps&&c.steps[0]&&c.steps[0].questions)||[]; const p=q.find(x=>x.id==='cli'); console.log(p&&p.default?p.default:'claude'); } catch(e){ console.log('claude'); }")
  [ -z "$PRD_OUT" ] && read -r -p "PRD path [$PRD_DEFAULT]: " PRD_OUT; PRD_OUT="${PRD_OUT:-$PRD_DEFAULT}"
  [ -z "$PROMPT" ] && read -r -p "Product/feature prompt: " PROMPT
  [ -z "$CLI" ] && read -r -p "CLI (claude|codex|cursor-agent) [$CLI_DEFAULT]: " CLI; CLI="${CLI:-$CLI_DEFAULT}"
else
  echo "[wizard] Step 1: PRD" >&2
  [ -z "$PRD_OUT" ] && read -r -p "PRD path [PRD.md]: " PRD_OUT; PRD_OUT="${PRD_OUT:-PRD.md}"
  [ -z "$PROMPT" ] && read -r -p "Product/feature prompt: " PROMPT
  [ -z "$CLI" ] && CLI="${PLAN_AN_GO_CLI:-claude}"
fi

[ -z "$PROMPT" ] && echo "ERROR: Prompt required" >&2 && exit 1

PRD_ABS=$(resolve_path "$PRD_OUT")
(cd "$ROOT" && PLAN_AN_GO_CLI="$CLI" "$SCRIPT_DIR/plan-an-go" prd --out "$PRD_ABS" --prompt="$PROMPT")
echo "WIZARD_PRD_PATH=$PRD_ABS" >> "$STATE_FILE"
echo "WIZARD_CLI=$CLI" >> "$STATE_FILE"
echo "[wizard] Step 1 done: $PRD_ABS" >&2
