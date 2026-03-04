# plan-an-go — Cursor config

Used by **Cursor** when working in this repo or when plan-an-go runs with `--cli cursor-agent`. Format follows [Cursor Rules](https://cursor.com/docs/context/rules): project rules in `.cursor/rules` (`.mdc` frontmatter: `description`, `globs`, `alwaysApply`).

- **Rules** (`rules/`): Bash/shell quality and fixing workflow. Use `.mdc` for path-scoped or always-apply rules.
- **Commands** (`commands/`): Lint, test, commit, review, CI.
- **Agents** (`agents/`): Code reviewer, test runner, verifier, debugger, security reviewer, researcher (tuned for plan-an-go).
- **Skills** (`skills/`): generate-plan, generate-prd; Cursor can load from `.claude/skills/` and `.codex/skills/` as well.

See [CLAUDE.md](../CLAUDE.md) and [AGENTS.md](../AGENTS.md) for project overview and commands.
