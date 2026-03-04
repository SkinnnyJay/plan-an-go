#!/bin/bash
# install-clis-windows.sh — Platform-specific installers for Windows (Git Bash / MSYS2 / Cygwin). Sourced by install-clis.sh.

install_claude() {
  if is_installed claude; then
    echo "  claude already installed."
    return 0
  fi
  echo "  Installing claude (Anthropic Claude Code CLI)..."
  npm install -g @anthropic-ai/claude-code
  if ! is_installed claude; then
    echo "  WARNING: claude may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  claude installed."
}

install_codex() {
  if is_installed codex; then
    echo "  codex already installed."
    return 0
  fi
  echo "  Installing codex (OpenAI Codex CLI)..."
  npm install -g @openai/codex
  if ! is_installed codex; then
    echo "  WARNING: codex may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  codex installed."
}

install_jq() {
  if is_installed jq; then
    echo "  jq already installed."
    return 0
  fi
  echo "  Installing jq..."
  if command -v winget &>/dev/null; then
    winget install --id jqlang.jq --accept-package-agreements --accept-source-agreements 2>/dev/null || {
      echo "  winget failed; try: choco install jq"
      return 1
    }
  elif command -v choco &>/dev/null; then
    choco install jq -y
  else
    echo "  Please install jq manually: winget install jqlang.jq   or   choco install jq"
    return 1
  fi
  if ! is_installed jq; then
    echo "  WARNING: jq may not be in PATH. Restart the terminal or add the install directory to PATH."
    return 1
  fi
  echo "  jq installed."
}

install_fswatch() {
  if is_installed fswatch; then
    echo "  fswatch already installed."
    return 0
  fi
  echo "  Installing fswatch (optional, for file watching)..."
  if command -v choco &>/dev/null; then
    choco install fswatch -y 2>/dev/null || {
      echo "  Please install fswatch manually if you need file-watch features (e.g. choco install fswatch)."
      return 1
    }
  else
    echo "  Please install fswatch manually if you need file-watch features (e.g. choco install fswatch)."
    return 1
  fi
  if ! is_installed fswatch; then
    echo "  WARNING: fswatch may not be in PATH after install."
    return 1
  fi
  echo "  fswatch installed."
}

check_cursor_agent() {
  if is_installed cursor-agent; then
    echo "  cursor-agent is in PATH."
    return 0
  fi
  echo "  cursor-agent not found. Install Cursor IDE; the agent is usually available when Cursor is installed."
  return 1
}
