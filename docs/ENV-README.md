# Environment variables

Copy `.env.sample` to `.env` and set values. This table lists every key, default, and when to use it.

**See also:** README.md (Quick start, commands), CLAUDE.md (Commands, output directory), `scripts/cli/README.md` (CLI scripts and `--out-dir`/`--workspace`).

| Key | Use | Default | Example | When to set |
|-----|-----|---------|---------|-------------|
| **Plan & pipeline** |
| `PLAN_FILE` | Path to the plan file (milestones/tasks). | `PLAN.md` | `PLAN.md`, `./my-plan.md` | When using a plan file not at repo root named `PLAN.md`. |
| `PLAN_AN_GO_ROOT` | Operating root for `scripts/plan-an-go` (where `PLAN.md` and `tmp/` live). | Directory containing `scripts/` (repo root) | `/path/to/project` | When running plan-an-go against another repo or folder. |
| `PLAN_AN_GO_TMP` | Directory for pipeline output: `progress.txt`, `history.log`, `pipeline-tail.log`, and agent artifact files (e.g. task output). When set (e.g. in `.env`), scripts use a **workspace-unique subdir** (hash of workspace path) so multiple workspaces do not append to the same files. | `./tmp` (relative to workspace) | `./tmp`, `/var/tmp/plan-an-go` | Override in `.env` to put all logs and temp files elsewhere; each workspace gets its own subdir. |
| `STREAM_OUTPUT` | Stream LLM output in real time with gray background. | `false` | `true` | When you want to watch implementer/validator output live. |
| `USE_SLACK` | Enable Slack posts from the pipeline. | `false` | `true`, `false` | By default Slack does not launch; set `true` or use `--slack-enable` to enable. If tokens are unset or a post fails, we warn and continue (no exit). |
| `SLACK_USE_THREADS` | Post pipeline updates in a single Slack thread. | `true` | `false` | Set `false` for flat channel messages (only when `USE_SLACK=true`). |
| `PLAN_AN_GO_VERBOSE` | Forever: full iteration summaries and plan-check output. | `false` | `true`, `false` | Or use `--verbose`; overrides default one-line progress. |
| `PLAN_AN_GO_QUIET` | Forever: only header, errors, and final completion/stop; no per-iteration progress. | `false` | `true`, `false` | Or use `--quiet`; useful for background runs. |
| **CLI auth** |
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude CLI. | (none) | `sk-ant-...` | To skip interactive auth when using `claude`. |
| `OPENAI_API_KEY` | OpenAI API key for Codex CLI; also used for TTS when `TTS_AFTER_TASK=true`. | (none) | `sk-...` | To skip interactive auth when using `codex`, or to enable spoken task summaries. |
| **Voice summary / TTS (optional)** |
| `TTS_AFTER_TASK` | After each completed task: play beep then speak a short LLM-generated summary via OpenAI TTS. | `false` | `true`, `false` | When you want spoken updates; requires `OPENAI_API_KEY` and `jq`. |
| `TTS_SUMMARY_PROMPT_FILE` | Path to the prompt template (placeholders: AGENT_ID, TASK_ID, TONE, etc.). Relative to repo root or absolute. | `assets/prompts/voice-summary.md` | `assets/prompts/voice-summary.md` | To customize structure of the announcement; this prompt is embedded in the pipeline. |
| `TTS_SUMMARY_MODEL` | OpenAI Chat model used to generate the summary text from the template. | `gpt-4o-mini` | `gpt-4o-mini`, `gpt-4o` | To use a different model for summary generation. |
| `TTS_TONE` | Tone for the announcement; injected into the prompt as `${TONE}`. | `professional` | `professional`, `friendly`, `warm`, `concise` | To change how the summary is phrased. |
| `TTS_MODEL` | OpenAI TTS model for speech. | `tts-1` | `tts-1`, `tts-1-hd` | `tts-1-hd` for higher quality. |
| `TTS_VOICE` | OpenAI TTS voice. | `alloy` | `alloy`, `echo`, `nova`, `shimmer` | To change the spoken voice. |
| `TTS_SPEED` | Speech speed (0.25 to 4.0; 1.0 = normal). | `1.0` | `1.0`, `1.2` | To speed up or slow down playback. |
| **CLI & models** |
| `PLAN_AN_GO_CLI` | Which CLI runs implementer/validator. | `claude` | `claude`, `codex`, `cursor-agent` | Set in `.env` for a consistent default; install and log into that CLI first for best results. |
| `PLAN_AN_GO_CLI_FLAGS` | Extra flags passed to the selected CLI (shared). | (none) | `--max-tokens 4096` | Overrides per-CLI flags when set. |
| `PLAN_AN_GO_CLAUDE_FLAGS` | Flags for Claude only (used when `PLAN_AN_GO_CLI_FLAGS` is unset). | (none) | `--max-tokens 4096` | Claude-specific overrides. |
| `PLAN_AN_GO_CODEX_FLAGS` | Flags for Codex only (used when `PLAN_AN_GO_CLI_FLAGS` is unset). | (none) | `--full-auto` | Codex-specific overrides. |
| `PLAN_AN_GO_CLAUDE_MODEL` | Claude model ID. | `claude-sonnet-4-20250514` | `claude-sonnet-4-20250514` | To use a different Claude model. |
| `PLAN_AN_GO_CODEX_MODEL` | Codex model ID. Empty = CLI default. | (none) | `codex-20250301` | When using Codex and you want a specific model. |
| **Slack (optional)** |
| `PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN` | Slack bot OAuth token (recommended for posting). | (none) | `xoxb-...` | Only when `USE_SLACK=true`; preferred over access token. |
| `PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN` | Slack user OAuth token (fallback). | (none) | `xoxp-...` or `xoxe-...` | When you don’t use a bot token. |
| `PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN` | Slack refresh token for renewing access token. | (none) | (from OAuth flow) | When using token refresh. |
| `PLAN_AN_GO_SLACK_APP_CLIENT_ID` | Slack app client ID (for token refresh). | (none) | (from Slack app) | With refresh token. |
| `PLAN_AN_GO_SLACK_APP_CLIENT_SECRET` | Slack app client secret (for token refresh). | (none) | (from Slack app) | With refresh token. |
| `PLAN_AN_GO_SLACK_APP_ID` | Slack app ID (metadata). | (none) | — | Only if your scripts/docs need it. |
| `PLAN_AN_GO_SLACK_APP_SIGNING_SECRET` | Slack signing secret (events). | (none) | — | Only for Slack event handling. |
| `PLAN_AN_GO_SLACK_APP_VERIFICATION_TOKEN` | Slack verification token. | (none) | — | Only if required by your app. |

**Internal (set by scripts, do not set in `.env`):** `PLAN_AN_GO_WORKSPACE` (passed as `--workspace` by entry script), `PLAN_AN_GO_AGENT_ID` (set when running with `--concurrency > 1`).

**Loading order:** `scripts/plan-an-go` loads `REPO_ROOT/.env`. Slack script loads `.env` then `.env.local` (so `.env.local` can override secrets).

---

## Output directory and cleanup (CLI flags)

These are **command-line flags**, not environment variables. Use them when running `plan-an-go` (or `npm run plan-an-go-*`).

| Flag | Subcommands | Purpose |
|------|-------------|---------|
| `--out-dir DIR` | run, forever, planner, prd | Use `DIR` as the workspace and for generated files. Dir is created if missing. **run/forever:** implement in `DIR`; **planner:** write `DIR/PLAN.md` (unless `--out` is set); **prd:** write `DIR/PRD.md` (unless `--out` is set). Use unique dirs per project (e.g. `./example/todo`, `./example/journal`) so runs do not overwrite each other. |
| `--workspace DIR` | run, forever, validate, task-watcher | Run the pipeline from `DIR`; plan path is relative to `DIR`. Overridden by `--out-dir` when both are used via the entry script. |
| `--clean-after` | forever only | After the pipeline exits (all tasks complete, max iterations, or Ctrl+C), remove all contents of the workspace directory. **Requires `--force`.** Cleanup runs only when the workspace is a **subdirectory** of the script repo (never repo root). |
| `--force` | forever (with `--clean-after`), reset | With `--clean-after`: confirm cleanup. With `reset`: skip backup of plan file. |

**Examples:** See README.md (Quick start, Option A) and CLAUDE.md (Commands, Output directory and cleanup).
