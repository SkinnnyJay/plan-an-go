# PRD — YouTube Clone with Real Videos (Large Project)

**Default output file:** `./PRD.md`

---

## Overview

A web application that mimics core YouTube functionality using **real video content** from YouTube: search via YouTube Data API v3, embed playback via YouTube IFrame Player API, and user-facing features such as watch history, watch later list, and saved playlists. The app is built with TypeScript, React, Next.js, and optional persistence (SQLite/Prisma or localStorage for watch-later and playlists). All frontend UI must be implemented with **shadcn/ui** components. Success is defined by search, playback of real YouTube videos, playlists, watch later, and E2E coverage of main flows.

---

## Goals

- **Goal 1:** Users can search for real YouTube videos using the YouTube Data API v3 (search.list) and see results (thumbnail, title, channel, view count, published date).
- **Goal 2:** Users can play videos in-app via the official YouTube IFrame Player API (embedded player); playback is real YouTube content, not placeholders.
- **Goal 3:** Users can add videos to a “Watch later” list and to custom playlists; lists are persisted (DB or localStorage).
- **Goal 4:** Users can view watch history (optional; persisted) and manage playlists (create, rename, reorder, remove videos).
- **Goal 5:** The entire UI is built with **shadcn/ui** components (Button, Input, Card, Dialog, Sheet, ScrollArea, Tabs, Skeleton, etc.) and Tailwind; no custom replacement UI for primary interactions.
- **Goal 6:** Strong typing (TypeScript, Zod at API boundaries), modular codebase, env-based API keys, and tests (unit + Playwright E2E) covering search, playback, watch later, and playlist flows.

---

## Non-goals (out of scope)

- Native mobile app; web-only.
- User accounts, authentication, or server-side watch history sync across devices in v1 (local or single-session persistence is acceptable).
- Uploading videos or commenting; consumption-only.
- Replacing YouTube’s own site for discovery; this is a focused clone with search + play + lists.

---

## User personas / stakeholders

- **Primary:** A user who wants to search and watch YouTube videos in a custom UI with watch-later and playlist support.
- **Secondary:** Developers maintaining the app; they need clear structure, env-based keys, and tests.

---

## Requirements

### Functional

- **F1:** User can enter a search query and receive results from YouTube Data API v3 (search.list); results show thumbnail, title, channel title, view count (formatted), and published date; results are real YouTube videos.
- **F2:** User can click a result to open a watch view; the video plays in an embedded YouTube player (IFrame API) so that real YouTube playback occurs (no mock or placeholder video).
- **F3:** Watch page shows video title, channel, description (from API), and a list of related or suggested videos (e.g. from search or from same channel) using real data.
- **F4:** User can add the currently watched video (or any video from search/results) to “Watch later”; Watch later list is persisted and viewable on a dedicated page.
- **F5:** User can remove items from Watch later and mark them as watched (optional: move to history).
- **F6:** User can create named playlists, add videos to a playlist, remove videos from a playlist, reorder videos (optional for v1), and delete a playlist.
- **F7:** User can view “My playlists” and open a playlist to see its videos and play any video from it in the embedded player.
- **F8:** Optional: watch history — list of recently watched videos (persisted); user can clear history.
- **F9:** All UI (search bar, result cards, video player container, watch later list, playlist forms, modals, sheets, buttons, inputs, tabs) must use **shadcn/ui** components from the project’s UI library; Tailwind and `cn()` for styling.
- **F10:** Next.js API routes (or server actions) for proxying YouTube API calls (search, video details) so that API keys are not exposed to the client; request/response validated with Zod.
- **F11:** Environment variables for YouTube API key (e.g. `YOUTUBE_API_KEY`) loaded via dotenv; documented in README or `.env.sample`; no secrets in source.

### Non-functional

- **NF1:** TypeScript strict mode; no `any`; types inferred from Zod at API boundaries.
- **NF2:** Modular structure: API client for YouTube, validation schemas, Prisma or store layer for watch-later/playlists, UI components; no single file over ~400 lines.
- **NF3:** Unit tests for validation, API response parsing, and playlist/watch-later logic under `__tests__`; Playwright E2E for: search and see results, open and play a video (embed loads), add to watch later, view watch later, create playlist and add video, view playlist and play video.
- **NF4:** YouTube IFrame Player API loaded per best practices (script tag or dynamic load); player state (play/pause/end) can be used for “mark as watched” or history if implemented.
- **NF5:** Use of `cn()` and Tailwind throughout; Radix/shadcn patterns only for primary UI.
- **NF6:** Rate limiting or quota awareness: document YouTube API quota and recommend minimal request patterns (e.g. cache search results briefly).

---

## Success criteria

- **SC1:** All functional requirements F1–F11 implemented and verifiable.
- **SC2:** All non-functional requirements NF1–NF6 met.
- **SC3:** Playwright E2E passes for: (1) search and display results, (2) open video and confirm embedded YouTube player loads and can play, (3) add to watch later and view list, (4) create playlist, add video, view playlist, play video from playlist.
- **SC4:** UI uses shadcn/ui components for all primary interactions (search, cards, player area, lists, dialogs, sheets).
- **SC5:** YouTube API key is server-side only (proxied or server actions); client never receives the key.
- **SC6:** Watch later and playlists persist across sessions (DB or localStorage); schema or storage format documented.
- **SC7:** README documents required env vars and how to obtain a YouTube Data API v3 key.

---

## Notes / assumptions / risks

- **Assumptions:** Next.js App Router; YouTube Data API v3 and IFrame Player API are used; API key has search and read access; persistence for watch-later/playlists can be SQLite/Prisma or localStorage for v1. shadcn/ui is installed and configured.
- **Risks:** YouTube API quota limits; recommend caching and minimal redundant requests. Embedding is subject to YouTube’s embed policy.
- **Dependencies:** Node.js 18+, npm/pnpm, Next.js, React, TypeScript, Zod, dotenv, shadcn/ui, Tailwind CSS, Prisma (optional), Playwright. YouTube Data API v3 and IFrame Player API (no npm package required for embed; script load is fine).
