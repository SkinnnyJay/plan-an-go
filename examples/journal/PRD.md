# PRD — Personal Journal (Medium Project)

**Default output file:** `./PRD.md`

---

## Overview

A personal journal web application where users create dated entries with title, body (markdown-supported), optional mood, and tags. Users can search entries, filter by tag or date range, and view a calendar or list view. The app is built with TypeScript, React, Next.js, Prisma, and SQLite. All frontend UI must be implemented with **shadcn/ui** components. Success is defined by full entry lifecycle, search/filter, and E2E coverage of main flows.

---

## Goals

- **Goal 1:** Users can create, read, update, and delete journal entries with title, body (markdown), optional mood, and tags.
- **Goal 2:** Entries are persisted in SQLite via Prisma with a normalized schema (entries, tags, entry-tag relation).
- **Goal 3:** Users can search entries by full-text (title + body), filter by one or more tags, and filter by date range.
- **Goal 4:** The entire UI is built with **shadcn/ui** components (Button, Input, Textarea, Card, Dialog, Select, Badge, Calendar, Tabs, etc.) and Tailwind; no custom replacement UI for primary interactions.
- **Goal 5:** List view and optional calendar-style view for browsing entries by date.
- **Goal 6:** Strong typing (TypeScript, Zod at API boundaries), modular codebase, and tests (unit + Playwright E2E) covering CRUD, search, and filter flows.

---

## Non-goals (out of scope)

- Native mobile app; web-only.
- Multi-user, authentication, or sharing in v1.
- Rich WYSIWYG editor; markdown in body is sufficient (rendered with a simple markdown renderer).
- Export to PDF or backup in v1.

---

## User personas / stakeholders

- **Primary:** Someone who keeps a daily or occasional journal and wants searchable, taggable entries in one place.
- **Secondary:** Developers maintaining the app; they need clear structure and tests.

---

## Requirements

### Functional

- **F1:** User can create a journal entry with title (required), body (required; markdown supported), optional mood (e.g. predefined set: Good, Okay, Low), and optional tags (multi-select or comma-separated); persisted via Prisma/SQLite.
- **F2:** User can list all entries with sort by date (newest/oldest first) and optional date-range filter (from/to).
- **F3:** User can filter entries by one or more tags (AND or OR configurable; at least OR for v1).
- **F4:** User can search entries by keyword (full-text on title and body); results shown in same list view.
- **F5:** User can view a single entry (detail view), edit it (title, body, mood, tags), and delete it.
- **F6:** List view shows entry title, date, mood, and tags; detail view shows full body with markdown rendered.
- **F7:** Optional calendar view: entries visible by date (e.g. dots or counts per day); clicking a day shows entries for that day.
- **F8:** All UI (forms, buttons, inputs, textareas, cards, dialogs, selects, badges, calendar, tabs) must use **shadcn/ui** components from the project's UI library; Tailwind and `cn()` for styling.
- **F9:** Next.js API routes for entry CRUD, search, and tag/list operations; all request/response bodies validated with Zod.
- **F10:** Environment variables (e.g. `DATABASE_URL`) via dotenv; documented in README or `.env.sample`.

### Non-functional

- **NF1:** TypeScript strict mode; no `any`; types inferred from Zod at boundaries.
- **NF2:** Modular structure: API routes, services, validation schemas, Prisma client, UI components; no single file over ~400 lines.
- **NF3:** Unit tests for validation, search/filter logic, and API handlers under `__tests__`; Playwright E2E for: create entry, list and sort, search, filter by tag, edit, delete, and (if implemented) calendar view.
- **NF4:** Markdown rendering via a single lightweight library (e.g. `react-markdown`); no custom parser required.
- **NF5:** Use of `cn()` and Tailwind throughout; Radix/shadcn patterns only for primary UI.

---

## Success criteria

- **SC1:** All functional requirements F1–F10 implemented and verifiable.
- **SC2:** All non-functional requirements NF1–NF5 met.
- **SC3:** Playwright E2E passes for: create entry with tags, list/sort, search by keyword, filter by tag, view detail, edit, delete; optional calendar flow if F7 is implemented.
- **SC4:** UI uses shadcn/ui components for all primary interactions (no custom replacements for Button, Input, Textarea, Card, Dialog, Select, Badge, etc.).
- **SC5:** Schema supports entries, tags, and entry-tag relationship; migrations and seed (if any) documented.
- **SC6:** Env and configuration documented; no secrets in source.

---

## Data strategy / mock data (for speed)

- **Use mock data first:** Implementation must support a fast path driven by **mock data** (multiple `.json` or `.jsonl` files) for development, seeding, and E2E tests—e.g. `mock/entries.jsonl`, `mock/tags.json`. The plan must include tasks to create these files and wire the app (or seed script) to load from them when appropriate (e.g. env flag or test fixtures).
- **DB as optional/secondary:** Prisma/SQLite can be used for persistence when not in mock mode; the plan should make it clear that mock data is the default for speed and that DB is optional or used only when mock data is disabled.

---

## Notes / assumptions / risks

- **Assumptions:** Next.js App Router; SQLite via Prisma; shadcn/ui installed and configured; single-user, no auth. Full-text search can use SQLite FTS or simple LIKE for v1.
- **Risks:** Large number of entries may require pagination or indexing; FTS recommended if search is central.
- **Dependencies:** Node.js 18+, npm/pnpm, Next.js, React, TypeScript, Prisma, SQLite, Zod, dotenv, shadcn/ui, Tailwind CSS, react-markdown (or similar), Playwright.
