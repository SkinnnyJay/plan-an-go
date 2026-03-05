# PRD — Todo List (Small Project)

**Default output file:** `./PRD.md`

---

## Overview

A minimal web-based todo list application for personal task management. Users can create, edit, complete, and delete tasks with optional due dates and filters. The app is built with TypeScript, React, Next.js, and SQLite (Prisma), with all UI implemented using **shadcn/ui** components. Success is defined by a clean CRUD flow, persistence, and passing E2E tests.

---

## Goals

- **Goal 1:** Users can manage a single todo list with full CRUD (create, read, update, delete) and mark tasks complete or incomplete.
- **Goal 2:** Tasks support title, optional description, optional due date, and completion state; all persisted via Prisma/SQLite.
- **Goal 3:** The UI is built entirely with **shadcn/ui** (Radix-based components): Button, Input, Checkbox, Card, Dialog, Select, etc., with Tailwind for layout.
- **Goal 4:** Users can filter tasks (all / active / completed) and sort by due date or created date.
- **Goal 5:** Codebase is typed (TypeScript, Zod at boundaries), modular, and covered by unit and Playwright E2E tests for core flows.

---

## Non-goals (out of scope)

- Native mobile app; web-only.
- Multi-user or authentication in v1.
- Recurring tasks, subtasks, or categories.
- Real-time sync or offline-first.

---

## User personas / stakeholders

- **Primary:** An individual who wants a simple, fast todo list in the browser with minimal setup.
- **Secondary:** Developers maintaining the app; they need clear types and tests.

---

## Requirements

### Functional

- **F1:** User can create a todo with title (required), optional description, and optional due date; data persisted via Prisma/SQLite.
- **F2:** User can list all todos with filters: All, Active (incomplete), Completed; and sort by due date (asc/desc) or created date (asc/desc).
- **F3:** User can update a todo (title, description, due date) and delete a todo.
- **F4:** User can toggle a todo’s completion state; state is persisted.
- **F5:** All list and form UI (inputs, buttons, checkboxes, dialogs, cards, selects) must use **shadcn/ui** components from the project’s `src/components/ui/` (or equivalent); no raw HTML form controls for primary interactions.
- **F6:** Next.js API routes for todo CRUD; request/response bodies validated with Zod.
- **F7:** Environment variables (e.g. `DATABASE_URL`) loaded via dotenv; documented in README or `.env.sample`.

### Non-functional

- **NF1:** TypeScript strict mode; no `any`; types inferred from Zod where appropriate.
- **NF2:** Modular structure: separate modules for API, validation schemas, Prisma client, and UI; no single file over ~400 lines.
- **NF3:** Unit tests for validation and core logic under `__tests__`; Playwright E2E tests for: create todo, list/filter/sort, edit, delete, toggle complete.
- **NF4:** Use of `cn()` from `@/lib/utils` with Tailwind for component styling; Radix/shadcn patterns throughout.

---

## Success criteria

- **SC1:** All functional requirements F1–F7 implemented and verifiable.
- **SC2:** All non-functional requirements NF1–NF4 met.
- **SC3:** Playwright E2E suite passes for: create, list with filter/sort, edit, delete, toggle completion.
- **SC4:** UI is implemented with shadcn/ui components only (no custom replacements for Button, Input, Checkbox, Card, Dialog, Select where they are used).
- **SC5:** `DATABASE_URL` and env usage documented; no secrets in source.

---

## Notes / assumptions / risks

- **Assumptions:** Next.js App Router; SQLite via Prisma; shadcn/ui is installed and configured (e.g. via `npx shadcn@latest init` and added components). Single-user, no auth.
- **Risks:** None significant for this scope.
- **Dependencies:** Node.js 18+, npm/pnpm, Next.js, React, TypeScript, Prisma, SQLite, Zod, dotenv, shadcn/ui, Tailwind CSS, Playwright.
