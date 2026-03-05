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

install_cline() {
  if is_installed cline; then
    echo "  cline already installed."
    return 0
  fi
  echo "  Installing cline (Cline CLI)..."
  brew install cline 2>/dev/null || npm install -g cline 2>/dev/null || {
    echo "  Fallback: see https://docs.cline.bot/cline-cli/getting-started"
    return 1
  }
  if ! is_installed cline; then
    echo "  WARNING: cline may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  cline installed."
}

install_copilot() {
  if is_installed copilot; then
    echo "  copilot already installed."
    return 0
  fi
  echo "  Installing copilot (GitHub Copilot CLI)..."
  brew install copilot-cli 2>/dev/null || npm install -g @github/copilot 2>/dev/null || {
    echo "  Fallback: see https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-in-the-cli"
    return 1
  }
  if ! is_installed copilot; then
    echo "  WARNING: copilot may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  copilot installed."
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

install_droid() {
  if is_installed droid; then
    echo "  droid already installed."
    return 0
  fi
  echo "  Installing droid (Factory.ai Droid CLI)..."
  curl -fsSL https://app.factory.ai/cli | sh 2>/dev/null || {
    echo "  Fallback: see https://app.factory.ai/cli"
    return 1
  }
  if ! is_installed droid; then
    echo "  WARNING: droid may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  droid installed."
}

install_gemini() {
  if is_installed gemini; then
    echo "  gemini already installed."
    return 0
  fi
  echo "  Installing gemini (Google Gemini CLI)..."
  npm install -g @google/gemini-cli 2>/dev/null || {
    echo "  Fallback: see https://github.com/google-gemini/gemini-cli"
    return 1
  }
  if ! is_installed gemini; then
    echo "  WARNING: gemini may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  gemini installed."
}

install_goose() {
  if is_installed goose; then
    echo "  goose already installed."
    return 0
  fi
  echo "  Installing goose (Block Goose CLI)..."
  curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash 2>/dev/null || brew install block-goose-cli 2>/dev/null || {
    echo "  Fallback: see https://github.com/block/goose"
    return 1
  }
  if ! is_installed goose; then
    echo "  WARNING: goose may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  goose installed."
}

install_kiro() {
  if is_installed kiro; then
    echo "  kiro already installed."
    return 0
  fi
  echo "  Installing kiro (Kiro CLI)..."
  curl -fsSL https://cli.kiro.dev/install | bash 2>/dev/null || {
    echo "  Fallback: see https://cli.kiro.dev/"
    return 1
  }
  if ! is_installed kiro; then
    echo "  WARNING: kiro may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  kiro installed."
}

install_opencode() {
  if is_installed opencode; then
    echo "  opencode already installed."
    return 0
  fi
  echo "  Installing opencode (OpenCode CLI)..."
  npm install -g opencode 2>/dev/null || {
    echo "  Fallback: see https://github.com/opencode-ai/opencode"
    return 1
  }
  if ! is_installed opencode; then
    echo "  WARNING: opencode may not be in PATH. Add the install directory to PATH."
    return 1
  fi
  echo "  opencode installed."
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
