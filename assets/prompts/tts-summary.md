# TTS summary prompt (post-task spoken announcement)

This prompt is used when TTS is enabled: after each completed task the pipeline asks an LLM to produce a short spoken summary, then speaks it via OpenAI TTS. You can customize the template to change tone and structure.

## Placeholders (substituted before sending to the LLM)

- `${AGENT_ID}` — e.g. `AGENT_01` or `The implementer`
- `${TASK_ID}` — e.g. `M1:2`
- `${TASK_DESCRIPTION}` — one-line task text from the plan
- `${MILESTONE}` — milestone title if available
- `${ITERATION}` — current iteration number
- `${CONFIDENCE}` — validator confidence score (e.g. 8/10)
- `${VERDICT}` — e.g. PASSED

The following are filled from implementer/validator output (truncated):

- `IMPLEMENTER_SUMMARY` — key lines from the implementer report (PLAN, FILES, VALIDATION)
- `VALIDATOR_SUMMARY` — verdict and confidence from the validator

---

## Instructions (customize below)

You are writing a brief spoken announcement for the user. Keep it under 50 words. Use natural language for text-to-speech: no markdown, no bullets, no asterisks. Write in a single paragraph.

Complete the announcement using this structure:

1. Who: "${AGENT_ID}" has completed a task.
2. What: Briefly state what was done (one sentence from the implementer summary).
3. Value: In one short sentence, say what we get from it (before/after or outcome).

Reply with ONLY the announcement text, nothing else. No quotes, no preamble.

---

## Context

**Task:** ${TASK_ID} — ${TASK_DESCRIPTION}
**Milestone:** ${MILESTONE}
**Iteration:** ${ITERATION}
**Validator:** ${VERDICT}, confidence ${CONFIDENCE}

**Implementer summary:**
IMPLEMENTER_SUMMARY

**Validator summary:**
VALIDATOR_SUMMARY
