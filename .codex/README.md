# plan-an-go — Codex config

Used by **Codex** when working in this repo. Codex discovers instructions from [AGENTS.md](https://developers.openai.com/codex/guides/agents-md) in the project root (and optional overrides); this directory holds rules and skills aligned with the plan-an-go Bash pipeline for tools that read `.codex/`.

- **Rules** (`rules/`): Bash/shell quality and fixing workflow (same layout as `.cursor/rules`).
- **Skills** (`skills/`): e.g. generate-plan; skill format compatible with [Agent Skills](https://agentskills.io/).

See [CLAUDE.md](../CLAUDE.md) and [AGENTS.md](../AGENTS.md) for project overview and commands.
