#!/bin/bash
# agent-colors.sh - Build per-agent color map from config or palette for task-watcher and forever.
# Usage: source this file, then call build_agent_color_map N [repo_root] and get_agent_color AGENT_ID.
# When USE_COLOR is false or stdout is not a TTY, get_agent_color returns empty.

# ANSI 8-color palette (index 0-7): red, green, yellow, blue, magenta, cyan, white, bright black
AGENT_PALETTE_ANSI=(31 32 33 34 35 36 37 90)
# Hex presets for nearest-color: same order (red, green, yellow, blue, magenta, cyan, white, gray)
AGENT_PALETTE_HEX=("ff0000" "00ff00" "ffff00" "0000ff" "ff00ff" "00ffff" "ffffff" "808080")

# Convert hex #rrggbb to nearest ANSI code (0-7 index into AGENT_PALETTE_ANSI).
hex_to_ansi() {
  local hex="$1"
  hex="${hex#[#]}"
  [ ${#hex} -ne 6 ] && echo "31" && return
  local r=$((0x${hex:0:2}))
  local g=$((0x${hex:2:2}))
  local b=$((0x${hex:4:2}))
  local best=0
  local best_sum=9999
  local presets=("255 0 0" "0 255 0" "255 255 0" "0 0 255" "255 0 255" "0 255 255" "255 255 255" "128 128 128")
  local i=0
  for p in "${presets[@]}"; do
    local pr pg pb
    read -r pr pg pb <<< "$p"
    local sum=$((${r:-0} > pr ? r - pr : pr - r))
    sum=$((sum + (${g:-0} > pg ? g - pg : pg - g)))
    sum=$((sum + (${b:-0} > pb ? b - pb : pb - b)))
    if [ "$sum" -lt "$best_sum" ]; then
      best_sum=$sum
      best=$i
    fi
    i=$((i + 1))
  done
  echo "${AGENT_PALETTE_ANSI[$best]}"
}

# Build color map for agents 1..N. Sets AGENT_COLOR_01, AGENT_COLOR_02, ... (ANSI escape string).
# Optional repo_root: path to repo containing agents/config.json.
# Config entries agents[].name (e.g. agent-01) and agents[].color (#rrggbb). #000 or default = use palette.
build_agent_color_map() {
  local n="${1:-1}"
  local repo_root="${2:-}"
  local config_file=""
  [ -n "$repo_root" ] && config_file="$repo_root/agents/config.json"
  [ -z "$repo_root" ] && config_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/agents/config.json"
  [ ! -f "$config_file" ] && config_file=""
  local default_hex="000000"
  if [ -n "$config_file" ] && command -v jq &>/dev/null; then
    default_hex=$(jq -r '.sub_agent_config.default_color // "#000000"' "$config_file" 2>/dev/null | tr -d '#') || default_hex="000000"
  fi
  local offset=0
  [ -n "$RANDOM" ] && offset=$((RANDOM % 8))
  local i=1
  while [ "$i" -le "$n" ]; do
    local agent_id
    agent_id=$(printf 'AGENT_%02d' "$i")
    local ansi_code=""
    if [ -n "$config_file" ] && command -v jq &>/dev/null; then
      local name
      name=$(printf 'agent-%02d' "$i")
      local hex
      hex=$(jq -r --arg n "$name" '.agents[] | select(.name==$n) | .color // ""' "$config_file" 2>/dev/null | tr -d '#')
      hex="${hex#[#]}"
      if [ -n "$hex" ] && [ "$hex" != "000" ] && [ "$hex" != "000000" ] && [ "$hex" != "$default_hex" ]; then
        ansi_code=$(hex_to_ansi "#$hex")
      fi
    fi
    [ -z "$ansi_code" ] && ansi_code="${AGENT_PALETTE_ANSI[$(((i - 1 + offset) % 8))]}"
    printf -v "AGENT_COLOR_%02d" "$i" $'\033['"${ansi_code}"'m'
    i=$((i + 1))
  done
  AGENT_COLOR_COUNT=$n
}

# Return ANSI escape for agent (e.g. AGENT_01). Empty if no color or color disabled.
get_agent_color() {
  local id="$1"
  [ -z "$id" ] && return
  if [ "${USE_COLOR:-true}" != "true" ]; then
    echo ""
    return
  fi
  if [ -t 1 ] 2>/dev/null || [ -t 2 ] 2>/dev/null; then
    :;
  else
    echo ""
    return
  fi
  case "$id" in
    AGENT_01) [ -n "${AGENT_COLOR_01:-}" ] && printf '%s' "${AGENT_COLOR_01}" ;;
    AGENT_02) [ -n "${AGENT_COLOR_02:-}" ] && printf '%s' "${AGENT_COLOR_02}" ;;
    AGENT_03) [ -n "${AGENT_COLOR_03:-}" ] && printf '%s' "${AGENT_COLOR_03}" ;;
    AGENT_04) [ -n "${AGENT_COLOR_04:-}" ] && printf '%s' "${AGENT_COLOR_04}" ;;
    AGENT_05) [ -n "${AGENT_COLOR_05:-}" ] && printf '%s' "${AGENT_COLOR_05}" ;;
    AGENT_06) [ -n "${AGENT_COLOR_06:-}" ] && printf '%s' "${AGENT_COLOR_06}" ;;
    AGENT_07) [ -n "${AGENT_COLOR_07:-}" ] && printf '%s' "${AGENT_COLOR_07}" ;;
    AGENT_08) [ -n "${AGENT_COLOR_08:-}" ] && printf '%s' "${AGENT_COLOR_08}" ;;
    AGENT_09) [ -n "${AGENT_COLOR_09:-}" ] && printf '%s' "${AGENT_COLOR_09}" ;;
    AGENT_10) [ -n "${AGENT_COLOR_10:-}" ] && printf '%s' "${AGENT_COLOR_10}" ;;
    *) ;;
  esac
}
