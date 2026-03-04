# plan-an-go — Claude Code project config

Used by the **Anthropic Claude CLI** when you run plan-an-go with `--cli claude`. Project scope: [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings) (`.claude/` is project-level; CLAUDE.md can live in repo root or here).

- **Rules** (`rules/`): Bash/shell quality and fixing workflow. File-type rules use frontmatter (`description`, `globs`, `alwaysApply`).
- **Skills** (`skills/`): Each skill is a directory with required `SKILL.md` (frontmatter: `name`, `description`). See [Extend Claude with skills](https://docs.anthropic.com/en/docs/claude-code/skills).
- **MCP**: optional servers in `mcp.json` (or `--mcp-config` when invoking the CLI).

See [CLAUDE.md](../CLAUDE.md) and [AGENTS.md](../AGENTS.md) for project overview and commands.
