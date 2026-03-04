# Agents config

`config.json` defines agents, swarms, and sub-agents. **Most fields are optional.** Consumers must not fail when optional fields are missing; they should apply defaults and optionally warn or log (e.g. debug) what was not set.

## Required vs optional

### Top-level

| Field           | Required | Default   | Notes |
|----------------|----------|-----------|--------|
| `agents`       | no       | `[]`      | List of agent entries. |
| `swarm`        | no       | `[]`      | List of swarm entries. |
| `sub_agents`   | no       | `[]`      | List of sub-agent entries. |
| `sub_agent_config` | no  | see below | Defaults for sub-agents (and fallbacks). |

### Per agent / swarm / sub-agent

| Field                     | Required | Default | Notes |
|---------------------------|----------|---------|--------|
| `name`                    | **yes**  | —       | Unique id. |
| `description`             | no       | `""`    | Human-readable label. |
| `model`                   | no       | from env or `gpt-4o-mini` | Model id. |
| `cli`                     | no       | `sub_agent_config.default_cli` or `codex` | CLI to run. |
| `cli_flags`               | no       | `sub_agent_config.default_cli_flags` or `""` | CLI flags. |
| `prompt_template_file`    | no       | none    | Path to prompt template; omit = no file. |
| `system_prompt_file`      | no       | none    | Path to system prompt file. |
| `user_prompt_file`        | no       | none    | Path to user prompt file. |
| `mcp_file`                | no       | none    | Path to MCP config JSON. |
| `parent_agent` (swarm)    | no       | —       | Reference to parent agent name. |
| `sub_agents` (swarm)      | no       | `[]`    | List of sub-agent names. |

### sub_agent_config

| Field             | Required | Default   |
|-------------------|----------|-----------|
| `default_cli`     | no       | `codex`   |
| `default_cli_flags` | no     | `--yolo`  |

## Behavior for consumers

- **Do not fail** when an optional field is absent; use the default.
- **Warn** (stderr) when a meaningful optional (e.g. `mcp_file`, `cli`) is missing and a default is used, if you want operators to notice.
- **Debug** (e.g. when `DEBUG=1` or `PLAN_AN_GO_AGENTS_DEBUG=1`): log each missing field and the default applied, so it’s clear what was not set.
- Resolve file paths (`*_file`) relative to repo root; if the file is missing, warn and continue (no prompt/MCP loaded for that slot).
