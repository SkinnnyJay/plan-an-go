#!/bin/bash
# plan-an-go-slack-update.sh — Post updates to #ralph-update Slack channel
# Usage:
#   # Direct invocation
#   ./plan-an-go-slack-update.sh "Hello from Plan-an-go!"
#   ./plan-an-go-slack-update.sh "Reply in thread" "1234567890.123456"  # With thread_ts
#
#   # Source and use functions
#   source ./plan-an-go-slack-update.sh
#   post_to_slack "Build completed successfully ✅"
#   post_to_slack "Thread reply" "$thread_ts"  # Reply to thread
#
#   # Capture thread_ts for threading
#   thread_ts=$(post_to_slack_get_ts "Starting iteration...")
#   post_to_slack_thread "Reply 1" "$thread_ts"
#   post_to_slack_thread "Reply 2" "$thread_ts"
#
# Environment Variables (use either set; PLAN_AN_GO_* from .env, SLACK_APP_* from .env.local):
#   PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN or SLACK_APP_BOT_OAUTH_TOKEN - Bot token (xoxb-..., recommended)
#   PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN or SLACK_APP_ACCESS_TOKEN - User token (fallback)
#   PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN or SLACK_APP_REFRESH_TOKEN - For token renewal (optional)
#   PLAN_AN_GO_SLACK_APP_CLIENT_ID or SLACK_CLIENT_ID - For token refresh (optional)
#   PLAN_AN_GO_SLACK_APP_CLIENT_SECRET or SLACK_CLIENT_SECRET - For token refresh (optional)
# Priority: PLAN_AN_GO_* (from .env) then SLACK_APP_* (from .env.local). Token: BOT > ACCESS.

# Load .env from repo root when present (so PLAN_AN_GO_SLACK_* are set), then .env.local overrides
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi
if [ -f .env.local ]; then
  set -a
  # shellcheck source=/dev/null
  source .env.local
  set +a
fi
[ "${BASH_SOURCE[0]}" = "$0" ] && set -e && set -o pipefail

# Constants
SLACK_CHANNEL_ID="C0AAS5RNNKX"
SLACK_CHANNEL_NAME="#ralph-update"
SLACK_API_URL="https://slack.com/api/chat.postMessage"
SLACK_OAUTH_REFRESH_URL="https://slack.com/api/oauth.v2.access"

# Global variable to store last message timestamp (for threading)
export SLACK_LAST_TS=""

# Refresh the Slack access token using the refresh token
# Returns: 0 on success (sets SLACK_APP_ACCESS_TOKEN), 1 on failure
refresh_slack_token() {
  local refresh_token="${PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN:-$SLACK_APP_REFRESH_TOKEN}"
  local client_id="${PLAN_AN_GO_SLACK_APP_CLIENT_ID:-$SLACK_CLIENT_ID}"
  local client_secret="${PLAN_AN_GO_SLACK_APP_CLIENT_SECRET:-$SLACK_CLIENT_SECRET}"
  if [ -z "$refresh_token" ]; then
    echo "❌ Error: PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN or SLACK_APP_REFRESH_TOKEN not set" >&2
    return 1
  fi

  echo "🔄 Refreshing Slack access token..." >&2

  local refresh_payload="grant_type=refresh_token&refresh_token=$refresh_token"
  if [ -n "$client_id" ] && [ -n "$client_secret" ]; then
    refresh_payload="$refresh_payload&client_id=$client_id&client_secret=$client_secret"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "$refresh_payload" \
    "$SLACK_OAUTH_REFRESH_URL")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ne 200 ]; then
    echo "❌ HTTP Error during token refresh: $http_code" >&2
    return 1
  fi

  if command -v jq &>/dev/null; then
    local ok new_access_token new_refresh_token
    ok=$(echo "$body" | jq -r '.ok // false')
    new_access_token=$(echo "$body" | jq -r '.authed_user.access_token // .access_token // ""')
    new_refresh_token=$(echo "$body" | jq -r '.authed_user.refresh_token // .refresh_token // ""')

    if [ "$ok" = "true" ] && [ -n "$new_access_token" ]; then
      export SLACK_APP_ACCESS_TOKEN="$new_access_token"
      export PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN="$new_access_token"
      [ -n "$new_refresh_token" ] && export SLACK_APP_REFRESH_TOKEN="$new_refresh_token"
      [ -n "$new_refresh_token" ] && export PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN="$new_refresh_token"
      echo "✅ Token refreshed successfully" >&2
      return 0
    fi
  fi

  echo "❌ Token refresh failed" >&2
  return 1
}

# Internal function to post message and return ts
# Usage: _post_to_slack_internal "message" [thread_ts] [quiet]
# Returns: ts on stdout, status messages on stderr
_post_to_slack_internal() {
  local message="$1"
  local thread_ts="$2"
  local quiet="$3"

  if [ -z "$message" ]; then
    echo "❌ Error: No message provided" >&2
    return 1
  fi

  # Sanitize problematic Unicode characters for consistent Slack rendering
  # Replace box-drawing characters with ASCII equivalents
  message=$(printf '%s' "$message" | sed \
    -e 's/━/-/g' \
    -e 's/═/=/g' \
    -e 's/│/|/g' \
    -e 's/┌/+/g' \
    -e 's/┐/+/g' \
    -e 's/└/+/g' \
    -e 's/┘/+/g' \
    -e 's/├/+/g' \
    -e 's/┤/+/g' \
    -e 's/┬/+/g' \
    -e 's/┴/+/g' \
    -e 's/┼/+/g' \
    -e 's/─/-/g' \
    -e 's/║/|/g' \
    -e 's/╔/+/g' \
    -e 's/╗/+/g' \
    -e 's/╚/+/g' \
    -e 's/╝/+/g')

  # Escape special characters for Slack mrkdwn format (required by Slack API)
  # Order matters: escape & first, then < and >
  message=$(printf '%s' "$message" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g')

  # Get token (prefer PLAN_AN_GO_* from .env, then SLACK_APP_* from .env.local)
  local token_to_use=""
  if [ -n "${PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN:-}" ]; then
    token_to_use="$PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN"
  elif [ -n "${SLACK_APP_BOT_OAUTH_TOKEN:-}" ]; then
    token_to_use="$SLACK_APP_BOT_OAUTH_TOKEN"
  elif [ -n "${PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN:-}" ]; then
    token_to_use="$PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN"
  elif [ -n "${SLACK_APP_ACCESS_TOKEN:-}" ]; then
    token_to_use="$SLACK_APP_ACCESS_TOKEN"
  fi

  if [ -z "$token_to_use" ]; then
    echo "❌ Error: No Slack token found" >&2
    return 1
  fi

  # Build JSON payload with proper escaping
  # Use jq for bulletproof JSON encoding (handles all special chars, unicode, etc.)
  local json_payload
  if command -v jq &>/dev/null; then
    # jq handles all JSON escaping automatically
    if [ -n "$thread_ts" ]; then
      json_payload=$(jq -n \
        --arg channel "$SLACK_CHANNEL_ID" \
        --arg text "$message" \
        --arg thread_ts "$thread_ts" \
        '{channel: $channel, text: $text, thread_ts: $thread_ts}')
    else
      json_payload=$(jq -n \
        --arg channel "$SLACK_CHANNEL_ID" \
        --arg text "$message" \
        '{channel: $channel, text: $text}')
    fi
  else
    # Fallback: manual escaping (less robust but works without jq)
    # Escape: backslash, quotes, tabs, control chars, then convert newlines
    local escaped_message
    escaped_message=$(printf '%s' "$message" |
      sed 's/\\/\\\\/g' |
      sed 's/"/\\"/g' |
      sed 's/	/\\t/g' |
      sed 's/\r/\\r/g' |
      tr '\n' '\036' |
      sed 's/\036/\\n/g')

    if [ -n "$thread_ts" ]; then
      json_payload="{\"channel\": \"$SLACK_CHANNEL_ID\", \"text\": \"$escaped_message\", \"thread_ts\": \"$thread_ts\"}"
    else
      json_payload="{\"channel\": \"$SLACK_CHANNEL_ID\", \"text\": \"$escaped_message\"}"
    fi
  fi

  # Status message
  if [ "$quiet" != "quiet" ]; then
    if [ -n "$thread_ts" ]; then
      echo "📤 Posting to $SLACK_CHANNEL_NAME (thread: $thread_ts)" >&2
    else
      echo "📤 Posting to $SLACK_CHANNEL_NAME" >&2
    fi
  fi

  # Make API request
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $token_to_use" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "$SLACK_API_URL")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ne 200 ]; then
    echo "❌ HTTP Error: $http_code" >&2
    return 1
  fi

  # Parse response
  if command -v jq &>/dev/null; then
    local ok error
    ok=$(echo "$body" | jq -r '.ok // false')
    error=$(echo "$body" | jq -r '.error // ""')

    if [ "$ok" = "true" ]; then
      local ts
      ts=$(echo "$body" | jq -r '.ts // ""')
      export SLACK_LAST_TS="$ts"

      if [ "$quiet" != "quiet" ]; then
        echo "✅ Posted (ts: $ts)" >&2
      fi

      # Output ts to stdout for capture
      echo "$ts"
      return 0
    else
      echo "❌ Slack API Error: $error" >&2
      return 1
    fi
  else
    # Fallback without jq
    if echo "$body" | grep -q '"ok":true'; then
      local ts
      ts=$(echo "$body" | grep -o '"ts":"[^"]*' | cut -d'"' -f4)
      export SLACK_LAST_TS="$ts"

      if [ "$quiet" != "quiet" ]; then
        echo "✅ Posted (ts: $ts)" >&2
      fi

      echo "$ts"
      return 0
    else
      echo "❌ Slack API Error" >&2
      return 1
    fi
  fi
}

# Post a message to Slack channel (or thread if thread_ts provided)
# Usage: post_to_slack "message" [thread_ts]
# Returns: 0 on success, 1 on failure
# Side effect: Sets SLACK_LAST_TS
post_to_slack() {
  local message="$1"
  local thread_ts="$2"

  _post_to_slack_internal "$message" "$thread_ts" >/dev/null
  return $?
}

# Post a message and return the timestamp (for starting threads)
# Usage: thread_ts=$(post_to_slack_get_ts "Your message here")
# Returns: message timestamp on stdout
post_to_slack_get_ts() {
  local message="$1"
  _post_to_slack_internal "$message" "" "quiet"
  return $?
}

# Post a reply to a thread
# Usage: post_to_slack_thread "Reply message" "$thread_ts"
# Returns: 0 on success, 1 on failure
post_to_slack_thread() {
  local message="$1"
  local thread_ts="$2"

  if [ -z "$thread_ts" ]; then
    echo "❌ Error: No thread_ts provided" >&2
    return 1
  fi

  _post_to_slack_internal "$message" "$thread_ts" "quiet" >/dev/null
  return $?
}

# CLI invocation
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ $# -eq 0 ]; then
    echo "Usage: $0 \"message\" [thread_ts]"
    echo ""
    echo "Examples:"
    echo "  $0 \"Build completed ✅\""
    echo "  $0 \"Reply\" \"1234567890.123456\""
    exit 1
  fi

  if [ -n "$2" ]; then
    _post_to_slack_internal "$1" "$2"
  else
    _post_to_slack_internal "$1"
  fi
  exit $?
fi
