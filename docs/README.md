# Documentation index

Central index for plan-an-go documentation. Use the table of contents to jump to a section or open a doc.

---

## Table of contents

| Section | Description |
|---------|-------------|
| [Reference docs](#reference-docs) | Command reference, environment variables |
| [Related docs](#related-docs) | README, CLAUDE, config |
| [Extending this documentation](#extending-this-documentation) | How to add or link new docs |

---

## Reference docs

Docs in this folder (`docs/`).

| Doc | Contents |
|-----|----------|
| [**COMMANDS.md**](COMMANDS.md) | **Command reference** — Full argument tables, examples, and when to use each command: `plan-an-go-forever`, `plan-an-go`, `plan-an-go-validate`, `plan-an-go-planner`, `plan-an-go-prd`, `plan-an-go-prd-from-plan`, `plan-an-go-task-watcher`, `reset`, `plan-an-go-plan-check`. Covers output/workspace (`--out-dir`), plan override (`--plan`), plan compliance (`<work>`, `--strict`), and generating PLAN from PRD. |
| [**CURSOR-SKILLS.md**](CURSOR-SKILLS.md) | **Cursor Agent Skills** — Documented skills for PRD and PLAN: `generate-prd` and `generate-plan`. How to invoke them in Cursor (`@generate-prd`, `@generate-plan`), when they’re valuable, and how they relate to the CLI. |
| [**ENV-README.md**](ENV-README.md) | **Environment variables** — Full table of keys, defaults, when to set. Output dir and cleanup (`--out-dir`, `--clean-after`, `--force`). [Setting up Slack](ENV-README.md#setting-up-slack-for-pipeline-updates). |

---

## Related docs

Live outside `docs/`; part of the overall documentation surface.

| Doc | Contents |
|-----|----------|
| [**../README.md**](../README.md) | Main README — Quick start, install, system setup, first-time use, commands summary, examples, project layout. Includes a [documentation](../README.md#documentation) section that links here. |
| [**../CLAUDE.md**](../CLAUDE.md) | Agent/CLAUDE context — Commands, plan file format, architecture, key env vars, output directory and cleanup. |
| [**../.env.sample**](../.env.sample) | Sample config — Copy to `.env` and set values; see ENV-README.md for full variable list. |
| [**../scripts/system/README.md**](../scripts/system/README.md) | System scripts — Setup, install-clis, auth-cli, verify; platform support. |
| [**../scripts/cli/README.md**](../scripts/cli/README.md) | CLI scripts — Implementer, validator, orchestrator, task-watcher, Slack; `--out-dir` / `--workspace`. |

---

## Extending this documentation

| Step | Action |
|------|--------|
| 1 | **New reference doc** — Create file in `docs/` (e.g. `docs/MY-TOPIC.md`). Add a row to the [Reference docs](#reference-docs) table with path and one-line description. |
| 2 | **New related doc** — If the doc lives outside `docs/`, add a row to the [Related docs](#related-docs) table with relative path and description. |
| 3 | **Main README** — In [README.md](../README.md), the [Documentation](../README.md#documentation) section has a summary table; add a row for any new doc that should be discoverable from the main readme. |
| 4 | **TOC** — If you add a new top-level section here (e.g. "Guides"), add a row to the [Table of contents](#table-of-contents) so the index stays scannable. |
