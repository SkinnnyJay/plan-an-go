# System scripts

Scripts to install CLIs, authenticate, and verify the environment for plan-an-go. Run from **repo root** (scripts resolve paths relative to repo root).

## Scripts

| Script | Purpose |
|--------|---------|
| **setup.sh** | Run install → auth → verify in order. Optional: `--skip-install`, `--skip-auth`, `--skip-verify`, `--force` (pass to verify). Extra args go to install-clis (e.g. `./setup.sh all`). |
| **install-clis.sh** | Install CLIs: `claude`, `codex`, `jq`, `fswatch`; check-only for `cursor-agent`. No args = interactive (y/n). `all` = install all; or list names. |
| **auth-cli.sh** | Authenticate selected CLIs (web login). Skips web login if `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` is set in `.env`/`.env.local`. `--logout [claude codex]` to log out. |
| **verify.sh** | Check `.env`, selected `PLAN_AN_GO_CLI` in PATH, auth (key or CLI login), optional Slack/jq. `--force` = warnings only, exit 0. |

## Quick reference

```bash
# From repo root

# Full setup (interactive)
./scripts/system/setup.sh

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
```

## Env

- **CLI choice:** `PLAN_AN_GO_CLI` in `.env` — `claude`, `codex`, or `cursor-agent`.
- **API keys (optional):** Set `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` in `.env` to skip web login for that provider.
- **Slack (optional):** `PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN`, `PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN`, etc. See repo root `.env.sample`.
