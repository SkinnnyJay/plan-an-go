# System scripts

Scripts to install CLIs, authenticate, and verify the environment for plan-an-go. Run from **repo root** (scripts resolve paths relative to repo root).

## Scripts

| Script | Purpose |
|--------|---------|
| **setup.sh** | Run link → install CLIs → auth → verify. Optional: `--skip-link`, `--skip-install`, `--skip-auth`, `--skip-verify`, `--force`. Extra args go to install-clis (e.g. `./setup.sh all`). |
| **install-plan-an-go.sh** | Link plan-an-go to npm global so `plan-an-go` is on PATH (`npm link` from repo root). Idempotent. Run as part of setup or via `plan-an-go install-plan-an-go` / `plan-an-go link`. |
| **install-clis.sh** | Install CLIs: `claude`, `codex`, `jq`, `fswatch`; check-only for `cursor-agent`. Dispatches to **install-clis-&lt;platform&gt;.sh** (darwin, linux, windows). No args = interactive (y/n). `all` = install all; or list names. |
| **install-clis-darwin.sh** | macOS installers (Homebrew, Claude install script, npm fallbacks). Sourced by install-clis.sh. |
| **install-clis-linux.sh** | Linux installers (apt-get, Homebrew if present, npm). Sourced by install-clis.sh. |
| **install-clis-windows.sh** | Windows installers (winget, Chocolatey, npm). For Git Bash / MSYS2 / Cygwin. Sourced by install-clis.sh. |
| **platform.sh** | Portable helpers: `get_platform` (darwin\|linux\|windows), `stat_mtime path`, `install_hint jq\|fswatch`. Source from other scripts for OS-neutral behavior. |
| **auth-cli.sh** | Authenticate selected CLIs (web login). Skips web login if `PLAN_AN_GO_ANTHROPIC_API_KEY` or `PLAN_AN_GO_OPENAI_API_KEY` is set in `.env`/`.env.local`. `--logout [claude codex]` to log out. |
| **verify.sh** | Check `.env`, selected `PLAN_AN_GO_CLI` in PATH, auth (key or CLI login), optional Slack/jq. `--force` = warnings only, exit 0. |
| **ci.sh** | Full CI gate: lint → format check → test. Used by `npm run ci` / `npm run build` and `make ci` / `make build`. Exit code = failed step or 0. |

## Quick reference

```bash
# From repo root

# Full setup (link plan-an-go + install CLIs + auth + verify)
./scripts/system/setup.sh

# Setup without linking plan-an-go to PATH
./scripts/system/setup.sh --skip-link

# Install all CLIs then auth and verify
./scripts/system/setup.sh all

# Install only claude and codex
./scripts/system/install-clis.sh claude codex

# Auth all (or interactive if no args)
./scripts/system/auth-cli.sh all

# Log out from claude
./scripts/system/auth-cli.sh --logout claude

# Verify environment (exit 1 on failure)
./scripts/system/verify.sh

# Verify but ignore failures (warnings only)
./scripts/system/verify.sh --force

# Full CI gate (lint → format → test; for CLI/CD)
./scripts/system/ci.sh
# or: npm run ci   make ci   make build
```

## Env

- **CLI choice:** `PLAN_AN_GO_CLI` in `.env` — `claude`, `codex`, or `cursor-agent`.
- **API keys (optional):** Set `PLAN_AN_GO_ANTHROPIC_API_KEY` or `PLAN_AN_GO_OPENAI_API_KEY` in `.env` to skip web login for that provider.
- **Slack (optional):** `PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN`, `PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN`, etc. See repo root `.env.sample`.
