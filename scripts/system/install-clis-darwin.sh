#!/bin/bash
# install-clis-darwin.sh — Platform-specific installers for macOS (Darwin). Sourced by install-clis.sh.

install_claude() {
  if is_installed claude; then
    echo "  claude already installed."
    return 0
  fi
  echo "  Installing claude (Anthropic Claude Code CLI)..."
  curl -fsSL https://claude.ai/install.sh | bash || {
    echo "  Fallback: npm install -g @anthropic-ai/claude-code"
    npm install -g @anthropic-ai/claude-code
  }
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
  brew install --cask codex 2>/dev/null || npm install -g @openai/codex
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
  brew install jq
  echo "  jq installed."
}

install_fswatch() {
  if is_installed fswatch; then
    echo "  fswatch already installed."
    return 0
  fi
  echo "  Installing fswatch (optional, for file watching)..."
  brew install fswatch
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
