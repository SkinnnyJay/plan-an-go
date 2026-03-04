#!/bin/bash
# plan-an-go-tts-summary.sh — Generate a short spoken summary after a task completes.
# Called by plan-an-go-forever.sh when TTS_AFTER_TASK=true and OPENAI_API_KEY is set.
# Uses OpenAI Chat to produce 1–3 sentences from the template, then OpenAI TTS to speak them.
#
# Usage: called by orchestrator with env or:
#   IMPL_OUTPUT=path VAL_OUTPUT=path PLAN_FILE=path ITERATION=n [AGENT_ID=...] [CONFIDENCE=...] [VERDICT=...] \
#   TTS_PROMPT_FILE=path OPENAI_API_KEY=key ./plan-an-go-tts-summary.sh
#
# Optional env: TTS_SUMMARY_PROMPT_FILE (default: assets/prompts/voice-summary.md), TTS_SUMMARY_MODEL (chat),
# TTS_TONE, TTS_MODEL (TTS), TTS_VOICE, TTS_SPEED, REPO_ROOT.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_DIR="${PLAN_AN_GO_TMP:-./tmp}"
mkdir -p "$TMP_DIR"

# Require OpenAI key
if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "⚠️  TTS skipped: OPENAI_API_KEY not set" >&2
  exit 0
fi

# Require implementer output
IMPL_OUTPUT="${IMPL_OUTPUT:-}"
VAL_OUTPUT="${VAL_OUTPUT:-}"
PLAN_FILE="${PLAN_FILE:-PLAN.md}"
ITERATION="${ITERATION:-0}"
AGENT_ID="${AGENT_ID:-The implementer}"
CONFIDENCE="${CONFIDENCE:-N/A}"
VERDICT="${VERDICT:-PASSED}"
# Prompt template: TTS_SUMMARY_PROMPT_FILE from .env, or TTS_PROMPT_FILE, or default voice-summary.md
TTS_PROMPT_FILE="${TTS_SUMMARY_PROMPT_FILE:-${TTS_PROMPT_FILE:-$REPO_ROOT/assets/prompts/voice-summary.md}}"
# If path is relative, resolve from REPO_ROOT
if [[ "$TTS_PROMPT_FILE" != /* ]]; then
  TTS_PROMPT_FILE="$REPO_ROOT/$TTS_PROMPT_FILE"
fi
TTS_SUMMARY_MODEL="${TTS_SUMMARY_MODEL:-gpt-4o-mini}"
TTS_TONE="${TTS_TONE:-professional}"
TTS_VOICE="${TTS_VOICE:-alloy}"
TTS_MODEL="${TTS_MODEL:-tts-1}"
TTS_SPEED="${TTS_SPEED:-1.0}"

if [ -z "$IMPL_OUTPUT" ] || [ ! -f "$IMPL_OUTPUT" ]; then
  echo "⚠️  TTS skipped: no implementer output file" >&2
  exit 0
fi

# Parse implementer output for task id and short summary
impl_content=$(cat "$IMPL_OUTPUT")
task_id=$(echo "$impl_content" | sed -n '/------START: IMPLEMENTER------/,/------END: IMPLEMENTER------/p' | grep -oE 'FEATURE:[[:space:]]*[M0-9]+:[0-9.]+' | head -1 | sed 's/FEATURE:[[:space:]]*//') || task_id=""
impl_section=$(echo "$impl_content" | sed -n '/------START: IMPLEMENTER------/,/------END: IMPLEMENTER------/p')
if [ -z "$impl_section" ]; then
  impl_section=$(echo "$impl_content" | head -80)
fi
# Truncate for prompt (first 400 chars, one line for display)
IMPLEMENTER_SUMMARY=$(echo "$impl_section" | head -30 | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-400)

# Task description and optional agent id from plan
task_description=""
if [ -n "$task_id" ] && [ -f "$PLAN_FILE" ]; then
  task_line=$(grep -m1 -E "\[x\] - ${task_id}-|\[ \] - ${task_id}-" "$PLAN_FILE" 2>/dev/null) || true
  if [ -n "$task_line" ]; then
    task_description=$(echo "$task_line" | sed -E "s/^.* - ${task_id}- *//" | sed 's/ \[AGENT_[0-9]*\]//g' | sed 's/  */ /g')
    if [ "$AGENT_ID" = "The implementer" ] && echo "$task_line" | grep -qE '\[AGENT_[0-9]+\]'; then
      AGENT_ID=$(echo "$task_line" | grep -oE '\[AGENT_[0-9]+\]' | tail -1 | tr -d '[]')
    fi
  fi
fi
[ -z "$task_description" ] && task_description="Task $task_id"

# Milestone: first **M<n>:0 - Title** before the task in the plan
milestone=""
if [ -f "$PLAN_FILE" ] && [ -n "$task_id" ]; then
  milestone=$(awk "/\*\*M[0-9]+:0 -/ { m=\$0 } /${task_id}/ { if (m) { sub(/^.*\*\*M[0-9]+:0 - /,\"\",m); sub(/\*\*.*/,\"\",m); print m; exit } }" "$PLAN_FILE" 2>/dev/null) || milestone=""
fi
[ -z "$milestone" ] && milestone="(current milestone)"

# Validator summary (if we have validator output)
VALIDATOR_SUMMARY=""
if [ -n "$VAL_OUTPUT" ] && [ -f "$VAL_OUTPUT" ]; then
  val_content=$(cat "$VAL_OUTPUT")
  VALIDATOR_SUMMARY=$(echo "$val_content" | sed -n '/------START: VALIDATOR------/,/------END: VALIDATOR------/p' | head -20 | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-300)
  [ -z "$VALIDATOR_SUMMARY" ] && VALIDATOR_SUMMARY=$(echo "$val_content" | head -15 | tr '\n' ' ' | cut -c1-300)
  # Override confidence/verdict from val output if not set
  if [ "$CONFIDENCE" = "N/A" ]; then
    c=$(echo "$val_content" | sed -n 's/.*CONFIDENCE SCORE: \([0-9]*\).*/\1/p' | head -1)
    [ -n "$c" ] && CONFIDENCE="$c/10"
  fi
  if [ "$VERDICT" = "PASSED" ]; then
    v=$(echo "$val_content" | sed -n 's/.*VERDICT: \([A-Z_]*\).*/\1/p' | head -1)
    [ -n "$v" ] && VERDICT="$v"
  fi
fi
[ -z "$VALIDATOR_SUMMARY" ] && VALIDATOR_SUMMARY="Validation complete. Verdict: $VERDICT."

# Load template
if [ ! -f "$TTS_PROMPT_FILE" ]; then
  echo "⚠️  TTS skipped: prompt file not found: $TTS_PROMPT_FILE" >&2
  exit 0
fi
prompt_template=$(cat "$TTS_PROMPT_FILE")

# Substitute placeholders (skip the markdown header block for the "prompt" we send; use full template)
# Replace placeholders
prompt_filled="$prompt_template"
prompt_filled="${prompt_filled//\$\{AGENT_ID\}/$AGENT_ID}"
prompt_filled="${prompt_filled//\$\{TASK_ID\}/$task_id}"
prompt_filled="${prompt_filled//\$\{TASK_DESCRIPTION\}/$task_description}"
prompt_filled="${prompt_filled//\$\{MILESTONE\}/$milestone}"
prompt_filled="${prompt_filled//\$\{ITERATION\}/$ITERATION}"
prompt_filled="${prompt_filled//\$\{CONFIDENCE\}/$CONFIDENCE}"
prompt_filled="${prompt_filled//\$\{VERDICT\}/$VERDICT}"
prompt_filled="${prompt_filled//\$\{TONE\}/$TTS_TONE}"
prompt_filled="${prompt_filled//IMPLEMENTER_SUMMARY/$IMPLEMENTER_SUMMARY}"
prompt_filled="${prompt_filled//VALIDATOR_SUMMARY/$VALIDATOR_SUMMARY}"

# Require jq for JSON request/response
if ! command -v jq &>/dev/null; then
  TTS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=../system/platform.sh
  . "$TTS_SCRIPT_DIR/../system/platform.sh"
  echo "⚠️  TTS skipped: jq required for OpenAI API calls (install with: $(install_hint jq))" >&2
  exit 0
fi

# Write prompt to temp file for safe JSON encoding
prompt_temp=$(mktemp "$TMP_DIR/tts-prompt.XXXXXX")
printf '%s' "$prompt_filled" > "$prompt_temp"
chat_response=$(mktemp "$TMP_DIR/tts-chat.XXXXXX")
tts_audio=$(mktemp "$TMP_DIR/tts-audio.XXXXXX.mp3")
cleanup() {
  rm -f "$prompt_temp" "$chat_response" "$tts_audio"
}
trap cleanup EXIT

# Call OpenAI Chat to get short summary text (use --rawfile to avoid shell escaping)
prompt_json=$(jq -n --rawfile content "$prompt_temp" --arg model "$TTS_SUMMARY_MODEL" '{model:$model,messages:[{role:"user",content:($content | tostring)}],max_tokens:150}')
if ! curl -sS -X POST "https://api.openai.com/v1/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$prompt_json" \
  -o "$chat_response"; then
  echo "⚠️  TTS skipped: OpenAI Chat request failed" >&2
  exit 0
fi

summary_text=$(jq -r '.choices[0].message.content // empty' "$chat_response" 2>/dev/null)
if [ -z "$summary_text" ]; then
  if jq -e '.error' "$chat_response" &>/dev/null; then
    echo "⚠️  TTS skipped: $(jq -r '.error.message' "$chat_response")" >&2
  else
    echo "⚠️  TTS skipped: no summary in response" >&2
  fi
  exit 0
fi

# Strip newlines and extra spaces for TTS (single paragraph)
summary_text=$(echo "$summary_text" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
if [ ${#summary_text} -gt 4096 ]; then
  summary_text="${summary_text:0:4090}..."
fi
printf '%s' "$summary_text" > "$prompt_temp"
# OpenAI TTS accepts optional speed (0.25 to 4.0)
speed_num=1.0
if [[ "$TTS_SPEED" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  s="${TTS_SPEED//[^0-9.]/}"
  if awk -v v="$s" 'BEGIN { exit (v >= 0.25 && v <= 4) ? 0 : 1 }' 2>/dev/null; then
    speed_num="$s"
  fi
fi
tts_json=$(jq -n --rawfile input "$prompt_temp" --arg model "$TTS_MODEL" --arg voice "$TTS_VOICE" --argjson speed "$speed_num" '{model:$model,input:($input | tostring),voice:$voice,speed:$speed}')

# Call OpenAI TTS
if ! curl -sS -X POST "https://api.openai.com/v1/audio/speech" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$tts_json" \
  -o "$tts_audio"; then
  echo "⚠️  TTS skipped: OpenAI TTS request failed" >&2
  exit 0
fi

if [ ! -s "$tts_audio" ]; then
  echo "⚠️  TTS skipped: empty audio response" >&2
  exit 0
fi

# Beep then play (macOS)
printf '\a'
if command -v afplay &>/dev/null; then
  afplay "$tts_audio" 2>/dev/null || true
fi

exit 0
