# PRD — &lt;Product or feature name&gt;

**Default output file:** `./PRD.md` (override with `--out` when using the PRD generator script.)

When generating via the PRD script or skills, include at the top a metadata block inside HTML comments (scripts add it automatically; skills should emit it) so previews do not render it:

<!-- 
```plan_meta_data
{"created_by":"plan-an-go-prd|generate-prd","created_at":"<ISO 8601>","last_updated":"<ISO 8601>","generated_cli":"<claude|codex|cursor-agent|gemini|goose|opencode>"}
```
-->

---

## Overview

2–4 sentences: what this product or feature is, who it is for, and why it matters. No implementation details here.

---

## Goals

- **Goal 1:** One-line outcome (e.g. "Users can sign in with SSO.")
- **Goal 2:** …
- **Goal 3:** …

---

## Non-goals (out of scope)

- What we are explicitly not doing in this PRD (e.g. "No mobile app in v1.")
- Keeps scope clear for planning and implementation.

---

## User personas / stakeholders

- **Primary:** Who is the main user? What do they need?
- **Secondary:** Other affected users or systems.
- Optional: one line each.

---

## Requirements

### Functional

- **F1:** Desirable, testable behavior (e.g. "System must export results to CSV.")
- **F2:** …
- **F3:** …

### Non-functional

- **NF1:** Performance, security, or quality (e.g. "API responses under 200ms p95.")
- **NF2:** …

---

## Success criteria

Testable conditions that define "done" for this product or feature. These can later be reflected in the PLAN's 100% success criteria.

- Criterion 1: e.g. "All F1–F3 implemented and covered by tests."
- Criterion 2: e.g. "Documentation updated."
- …

---

## Notes / assumptions / risks

Optional: dependencies, assumptions, open questions, or risks. Links to design docs or PRs.
