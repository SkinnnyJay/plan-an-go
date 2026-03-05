# Environment variables

Copy `.env.sample` to `.env` and set values. This doc lists every key, default, and when to use it.

---

## Table of contents

| Section | Description |
|---------|-------------|
| [Variable table](#variable-table) | All keys, use, default, example, when to set |
| [Internal and loading](#internal-and-loading) | Internal vars; loading order |
| [Setting up Slack](#setting-up-slack-for-pipeline-updates) | Slack app, bot token, channel |
| [Output directory and cleanup](#output-directory-and-cleanup-cli-flags) | CLI flags: `--out-dir`, `--clean-after`, `--force` |

**See also:** [COMMANDS.md](COMMANDS.md) | [README](../README.md) | [CLAUDE.md](../CLAUDE.md) | [scripts/cli/README.md](../scripts/cli/README.md)

---

## Variable table

| Key | Use | Default | Example | When to set |
|-----|-----|---------|---------|-------------|
| **Plan & pipeline** |
| `PLAN_FILE` | Path to the plan file (milestones/tasks). | `PLAN.md` | `PLAN.md`, `./my-plan.md` | When using a plan file not at repo root named `PLAN.md`. |
| `PLAN_AN_GO_ROOT` | Operating root for `scripts/plan-an-go` (where `PLAN.md` and `tmp/` live). | Directory containing `scripts/` (repo root) | `/path/to/project` | When running plan-an-go against another repo or folder. |
| `PLAN_AN_GO_TMP` | Directory for pipeline output: `progress.log`, `history.log`, `pipeline-tail.log`, and agent artifact files (e.g. task output). When set (e.g. in `.env`), scripts use a **workspace-unique subdir** (hash of workspace path) so multiple workspaces do not append to the same files. | `./tmp` (repo/workspace root) | `./tmp`, `/var/tmp/plan-an-go` | Override in `.env` (or by passing the env var on the command line) to put all logs and temp files elsewhere; each workspace gets its own subdir. |
| `PLAN_AN_GO_STREAM_OUTPUT` | Stream LLM output in real time with gray background. | `false` | `true` | When you want to watch implementer/validator output live. |
| `PLAN_AN_GO_USE_SLACK` | Enable Slack posts from the pipeline. | `false` | `true`, `false` | By default Slack does not launch; set `true` or use `--slack-enable` to enable. If tokens are unset or a post fails, we warn and continue (no exit). |
| `PLAN_AN_GO_SLACK_USE_THREADS` | Post pipeline updates in a single Slack thread. | `true` | `false` | Set `false` for flat channel messages (only when `PLAN_AN_GO_USE_SLACK=true`). |
| `PLAN_AN_GO_VERBOSE` | Forever: full iteration summaries and plan-check output. | `false` | `true`, `false` | Or use `--verbose`; overrides default one-line progress. |
| `PLAN_AN_GO_QUIET` | Forever: only header, errors, and final completion/stop; no per-iteration progress. | `false` | `true`, `false` | Or use `--quiet`; useful for background runs. |
| `PLAN_AN_GO_STRICT` | Require plan to be `<work>`-compliant (milestones and tasks inside `<work>...</work>`). Non-compliant plans exit 1. | `false` | `true`, `false` | Or use `--strict` on forever, run, or plan-check; see README. |
| **CLI auth** |
| `PLAN_AN_GO_ANTHROPIC_API_KEY` | Anthropic API key for Claude CLI. | (none) | `sk-ant-...` | To skip interactive auth when using `claude`. |
| `PLAN_AN_GO_OPENAI_API_KEY` | OpenAI API key for Codex CLI; also used for TTS when `PLAN_AN_GO_TTS_AFTER_TASK=true`. | (none) | `sk-...` | To skip interactive auth when using `codex`, or to enable spoken task summaries. |
| **Voice summary / TTS (optional)** |
| `PLAN_AN_GO_TTS_AFTER_TASK` | After each completed task: play beep then speak a short LLM-generated summary via OpenAI TTS. | `false` | `true`, `false` | When you want spoken updates; requires `PLAN_AN_GO_OPENAI_API_KEY` and `jq`. |
| `PLAN_AN_GO_TTS_SUMMARY_PROMPT_FILE` | Path to the prompt template (placeholders: AGENT_ID, TASK_ID, TONE, etc.). Relative to repo root or absolute. | `assets/prompts/voice-summary.md` | `assets/prompts/voice-summary.md` | To customize structure of the announcement; this prompt is embedded in the pipeline. |
| `PLAN_AN_GO_TTS_SUMMARY_MODEL` | OpenAI Chat model used to generate the summary text from the template. | `gpt-4o-mini` | `gpt-4o-mini`, `gpt-4o` | To use a different model for summary generation. |
| `PLAN_AN_GO_TTS_TONE` | Tone for the announcement; injected into the prompt as `${TONE}`. | `professional` | `professional`, `friendly`, `warm`, `concise` | To change how the summary is phrased. |
| `PLAN_AN_GO_TTS_MODEL` | OpenAI TTS model for speech. | `tts-1` | `tts-1`, `tts-1-hd` | `tts-1-hd` for higher quality. |
| `PLAN_AN_GO_TTS_VOICE` | OpenAI TTS voice. | `alloy` | `alloy`, `echo`, `nova`, `shimmer` | To change the spoken voice. |
| `PLAN_AN_GO_TTS_SPEED` | Speech speed (0.25 to 4.0; 1.0 = normal). | `1.0` | `1.0`, `1.2` | To speed up or slow down playback. |
| **Sounds (forever)** |
| `PLAN_AN_GO_SOUND_ENABLED` | Play sounds after each task, on failure, and when plan is complete (macOS: afplay). | `true` | `true`, `false` | Set `false` to disable all sounds. |
| `PLAN_AN_GO_SOUND_TASK` | Sound file for task/iteration complete. | `Bottle.aiff` (system) | `/path/to/sound.aiff` | Override with a custom sound. |
| `PLAN_AN_GO_SOUND_FAIL` | Sound file when implementer fails, validator reverts, or credits exhausted. | `Funk.aiff` (system) | `/path/to/fail.aiff` | Override failure sound. |
| `PLAN_AN_GO_SOUND_PLAN_DONE` | Sound file when all tasks are complete. | `Hero.aiff` (system) | `/path/to/done.aiff` | Override plan-complete sound. |
| **CLI & models** |
| `PLAN_AN_GO_CLI` | Which CLI runs implementer/validator. | `claude` | `claude`, `codex`, `cursor-agent` | Set in `.env` for a consistent default; install and log into that CLI first for best results. |
| `PLAN_AN_GO_CLI_FLAGS` | Extra flags passed to the selected CLI (shared). | (none) | `--max-tokens 4096` | Overrides per-CLI flags when set. |
| `PLAN_AN_GO_CLAUDE_FLAGS` | Flags for Claude only (used when `PLAN_AN_GO_CLI_FLAGS` is unset). | (none) | `--max-tokens 4096` | Claude-specific overrides. |
| `PLAN_AN_GO_CODEX_FLAGS` | Flags for Codex only (used when `PLAN_AN_GO_CLI_FLAGS` is unset). | (none) | `--full-auto` | Codex-specific overrides. |
| `PLAN_AN_GO_CLAUDE_MODEL` | Claude model ID. | `claude-sonnet-4-20250514` | `claude-sonnet-4-20250514` | To use a different Claude model. |
| `PLAN_AN_GO_CODEX_MODEL` | Codex model ID. Empty = CLI default. | (none) | (varies by account) | Leave **unset** for ChatGPT/OpenAI accounts (Codex picks a supported model). Set only if your Codex account supports a specific model ID. |
| `PLAN_AN_GO_TASK_DETAIL` | Planner: task granularity (L=low, M=medium, H=high, XH=extra high). | `M` | `L`, `M`, `H`, `XH` | Override default when generating PLAN.md; use `--task-detail` on the planner for one-off runs. |
| **Slack (optional)** |
| `PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN` | Slack bot OAuth token (recommended for posting). | (none) | `xoxb-...` | Only when `PLAN_AN_GO_USE_SLACK=true`; preferred over access token. |
| `PLAN_AN_GO_SLACK_APP_ACCESS_TOKEN` | Slack user OAuth token (fallback). | (none) | `xoxp-...` or `xoxe-...` | When you don’t use a bot token. |
| `PLAN_AN_GO_SLACK_APP_REFRESH_TOKEN` | Slack refresh token for renewing access token. | (none) | (from OAuth flow) | When using token refresh. |
| `PLAN_AN_GO_SLACK_APP_CLIENT_ID` | Slack app client ID (for token refresh). | (none) | (from Slack app) | With refresh token. |
| `PLAN_AN_GO_SLACK_APP_CLIENT_SECRET` | Slack app client secret (for token refresh). | (none) | (from Slack app) | With refresh token. |
| `PLAN_AN_GO_SLACK_APP_ID` | Slack app ID (metadata). | (none) | — | Only if your scripts/docs need it. |
| `PLAN_AN_GO_SLACK_APP_SIGNING_SECRET` | Slack signing secret (events). | (none) | — | Only for Slack event handling. |
| `PLAN_AN_GO_SLACK_APP_VERIFICATION_TOKEN` | Slack verification token. | (none) | — | Only if required by your app. |

---

## Internal and loading

### Internal (do not set in `.env`)

| Variable | Set by | Purpose |
|----------|--------|---------|
| `PLAN_AN_GO_WORKSPACE` | Entry script (as `--workspace`) | Current workspace path. |
| `PLAN_AN_GO_AGENT_ID` | Orchestrator when `--concurrency > 1` | Agent id (e.g. AGENT_01). |
| `PLAN_AN_GO_SKIP_COMMIT` | Orchestrator when workspace under repo `tmp/` | Implementer skips git commit to avoid sandbox/permission errors. |

### Loading order

- **`scripts/plan-an-go`** loads `REPO_ROOT/.env`.
- **Slack script** loads `.env` then `.env.local` (`.env.local` overrides secrets).

---

## Setting up Slack for pipeline updates

When `PLAN_AN_GO_USE_SLACK=true` (or you pass `--slack-enable`), the forever pipeline posts task and completion updates to a Slack channel. You need a Slack app with a bot token and the right scopes.

**Slack API:** [api.slack.com/start](https://api.slack.com/start/overview)

### 1. Create a Slack app and bot

1. Go to [Slack API: Your Apps](https://api.slack.com/apps) and click **Create New App** → **From scratch**.
2. Name the app (e.g. “plan-an-go”) and pick the workspace to install it in.
3. Under **OAuth & Permissions**, add Bot Token Scopes: `chat:write` (and `channels:read` / `groups:read` if you need to resolve channel names).
4. Under **Install App**, install the app to your workspace.
5. Copy the **Bot User OAuth Token** (starts with `xoxb-`).

Slack’s own guides go into more detail:

- [Creating a Slack app](https://api.slack.com/authentication/basics#creating)
- [Bot users and tokens](https://api.slack.com/authentication/basics#scopes) (scopes and OAuth)
- [Sending messages](https://api.slack.com/messaging/sending-messages) (how `chat.postMessage` works)

### 2. Set your `.env`

Copy `.env.sample` to `.env` (if you haven’t already), then set at least:

```bash
PLAN_AN_GO_USE_SLACK=true
PLAN_AN_GO_SLACK_APP_BOT_OAUTH_TOKEN=xoxb-your-token-here
```

Keep `.env` out of version control. For local overrides (e.g. a different token), the Slack script also loads `.env.local` after `.env`.

Optional: to post in a single thread, keep `PLAN_AN_GO_SLACK_USE_THREADS=true` (default). To post as separate messages, set it to `false`. The channel ID and name are configured in `scripts/cli/plan-an-go-slack-update.sh`; change those constants if you want a different channel.

### 3. Invite the bot to the channel

In Slack, invite the app’s bot user to the channel where updates should go (e.g. `/invite @YourAppBot` in that channel). Without this, `chat.postMessage` can fail with “channel_not_found” or “not_in_channel”.

### 4. Run with Slack enabled

Use the forever command with Slack on:

```bash
npm run plan-an-go-forever -- --out-dir ./example/todo --plan PLAN.md --slack-enable
```

If the token is missing or a post fails, the pipeline logs a warning and continues (it does not exit).

---

## Output directory and cleanup (CLI flags)

**Command-line flags**, not environment variables. Use when running `plan-an-go` or `npm run plan-an-go-*`.

### Flag reference

| Flag | Subcommands | Purpose |
|------|-------------|---------|
| `--out-dir DIR` | run, forever, planner, prd | Use `DIR` as the workspace and for generated files. Dir is created if missing. **run/forever:** implement in `DIR`; **planner:** write `DIR/PLAN.md` (unless `--out` is set); **prd:** write `DIR/PRD.md` (unless `--out` is set). Use unique dirs per project (e.g. `./example/todo`, `./example/journal`) so runs do not overwrite each other. |
| `--task-detail L/M/H/XH` | planner | Task granularity: **L** (low, fewer coarser tasks), **M** (medium, default), **H** (high, more granular), **XH** (extra high, maximum detail). Affects how many tasks and subtasks the planner emits. |
| `--workspace DIR` | run, forever, validate, task-watcher | Run the pipeline from `DIR`; plan path is relative to `DIR`. Overridden by `--out-dir` when both are used via the entry script. |
| `--clean-after` | forever only | After the pipeline exits (all tasks complete, max iterations, or Ctrl+C), remove all contents of the workspace directory. **Requires `--force`.** Cleanup runs only when the workspace is a **subdirectory** of the script repo (never repo root). |
| `--force` | forever (with `--clean-after`), reset | With `--clean-after`: confirm cleanup. With `reset`: skip backup of plan file. |

**See also:** [README](../README.md) (Quick start, Option A), [CLAUDE.md](../CLAUDE.md) (Commands, Output directory and cleanup).
