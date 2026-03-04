# Cursor / Agent Skills project config

This directory is used by **Cursor** when you run plan-an-go with `--cli cursor-agent`.

- **Skills** in `skills/` are loaded by Cursor as project-level [Agent Skills](https://cursor.com/docs/context/skills).
- Cursor also reads from `.cursor/` (rules, commands, MCP). For compatibility it can load skills from `.claude/skills/` and `.codex/skills/` as well.

Docs: [Agent Skills](https://cursor.com/docs/context/skills).
