# PRD — Vacation Planning TODO (Airbnb + Table-Stake Features)

**Default output file:** `./PRD.md`

---

## Overview

A web application that helps users plan a vacation by maintaining a structured TODO list integrated with Airbnb APIs. Users can create, organize, and track vacation tasks (flights, packing, bookings, activities) and optionally discover or link Airbnb listings. The app is built with TypeScript, React, Next.js, Prisma, and SQLite, with strong typing (Zod at boundaries), a modular DRY codebase, and comprehensive testing (unit, integration, and Playwright E2E). Success is defined by E2E tests that cover all features and happy paths.

---

## Goals

- **Goal 1:** Users can manage a vacation TODO list with full CRUD (create, read, update, delete) and table-stake features (filters, sort, due dates, completion state).
- **Goal 2:** The app integrates with Airbnb APIs (search/listings where applicable) so users can add “book Airbnb”–style tasks and optionally attach listing references.
- **Goal 3:** Data is persisted in SQLite via Prisma with a clean schema; configuration uses dotenv and no secrets in code.
- **Goal 4:** The codebase is strongly typed (TypeScript, Zod at API/DB boundaries), DRY, and modular—no large monolith files; modern JavaScript/React patterns throughout.
- **Goal 5:** Test criteria are defined and satisfied by unit tests in `__tests__`, integration tests where appropriate, and Playwright E2E tests that pass for all features and happy paths.

---

## Non-goals (out of scope)

- Native mobile apps (web-only in scope).
- Full Airbnb booking/payment flow inside the app (integration is for discovery/reference only).
- Multi-tenant or real-time collaboration in v1.
- Replacing Airbnb’s official app for actual bookings.

---

## User personas / stakeholders

- **Primary:** A traveler planning a vacation who wants one place to track tasks (pack, book flight, book stay, plan activities) and optionally link or search Airbnb listings.
- **Secondary:** Developers maintaining the app; they need clear structure, types, and tests to iterate safely.

---

## Requirements

### Functional

- **F1:** User can create a vacation TODO item with title, optional description, due date, and completion state; all persisted via Prisma/SQLite.
- **F2:** User can list all TODOs with optional filters (e.g. by completion state, by date range) and sort (e.g. by due date, created date).
- **F3:** User can update an existing TODO (title, description, due date, completed) and delete a TODO.
- **F4:** User can mark a TODO as complete or incomplete (toggle); state is persisted.
- **F5:** The app integrates with Airbnb APIs (e.g. search or fetch listing details) so that users can add a “Book Airbnb”–type task and optionally attach or display an Airbnb listing ID or summary (exact endpoints to be chosen during implementation; at least one read-oriented Airbnb API usage required).
- **F6:** A clear, navigable UI for the TODO list (e.g. list view, add/edit forms, filters/sort controls) built with React and Next.js.
- **F7:** API routes (Next.js) for TODO CRUD and, where applicable, for proxying or wrapping Airbnb API calls; all request/response bodies validated with Zod.
- **F8:** Environment variables (e.g. API keys, `DATABASE_URL`) are loaded via dotenv and documented; no secrets in source.

### Non-functional

- **NF1:** TypeScript strict mode; no `any`; types inferred from Zod where appropriate (e.g. `z.infer<typeof TodoSchema>`).
- **NF2:** File and folder structure is modular and DRY: separate modules for API client, validation schemas, Prisma client, UI components, and pages; no single file exceeding a reasonable line limit (e.g. 300–400 lines for a single module; split if larger).
- **NF3:** Unit tests for pure logic and utilities live under `__tests__` (e.g. `__tests__/unit/`, `__tests__/integration/` as needed); naming convention consistent with the project (e.g. `*.test.ts` or `*.spec.ts`).
- **NF4:** E2E tests use Playwright; they cover the main user flows (create TODO, list/filter/sort, edit, delete, mark complete) and the happy path of any Airbnb-backed flow (e.g. search or link a listing). All E2E tests must pass for the feature set to be considered done.
- **NF5:** Use of modern JavaScript/React patterns (e.g. async/await, hooks, server components where appropriate, optional chaining, structured error handling) and avoid legacy patterns or monolithic components.

---

## Success criteria

- **SC1:** All functional requirements F1–F8 are implemented and verifiable.
- **SC2:** All non-functional requirements NF1–NF5 are met (typed codebase, modular structure, tests in `__tests__`, Playwright E2E in place).
- **SC3:** Playwright E2E test suite exists and passes for: (1) creating a TODO, (2) listing and filtering/sorting TODOs, (3) editing a TODO, (4) deleting a TODO, (5) toggling completion, (6) happy path for Airbnb integration (e.g. search or link listing and show result).
- **SC4:** Unit and/or integration tests cover critical logic (e.g. validation, API route handlers, service layer) in `__tests__`.
- **SC5:** Environment is configured via dotenv; `DATABASE_URL` and any API keys are documented (e.g. in README or `.env.sample`) and not committed.
- **SC6:** No monolith files; module and file organization is reviewed and adheres to the stated line limits and separation of concerns.

---

## Notes / assumptions / risks

- **Assumptions:** (1) Airbnb API access (e.g. RapidAPI or official partner endpoints) is available and terms allow read-only use for this app. (2) Next.js App Router is used unless the project explicitly adopts Pages Router. (3) SQLite is acceptable for single-user or small-scale use; Prisma schema should be easy to swap to another DB later if needed.
- **Risks:** Airbnb API rate limits or key availability may constrain the integration; the PRD requires “at least one” meaningful Airbnb integration (e.g. search/listings) so the product is distinguishable from a generic TODO app.
- **Dependencies:** Node.js 18+, npm/pnpm, Prisma, Next.js, React, TypeScript, Zod, dotenv, Playwright. Optional: a small API client module for Airbnb calls to keep pages and API routes thin.
