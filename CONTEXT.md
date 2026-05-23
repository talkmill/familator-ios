# Familator domain

A personal/family productivity app: workspaces hold lists of todos, plus travel planning and Google Calendar sync. Web (Next.js + Supabase), Electron desktop, iOS app — all backed by the same Supabase project.

## Language

### Identity & permissioning

**Workspace**:
A container that owns lists, members, and invitations; a user can belong to multiple workspaces and has one active at a time.
_Avoid_: org, team, family group

**Workspace Member**:
A user joined to a workspace with a role (owner, editor, viewer).
_Avoid_: collaborator, account

**Workspace Invitation**:
An email-addressed offer to join a workspace; has its own lifecycle (send → accept / decline / revoke).
_Avoid_: invite token

### Lists & todos

**List**:
A named collection of todos within a workspace. Concrete kinds: **Inbox List**, **Trip List**. Distinct from the three "virtual lists" below.
_Avoid_: project, folder, board, category

**Inbox List**:
The default `lists` row a user lands on; one per workspace per user. A real `List` row, just specially named.
_Avoid_: default list, unsorted

**Trip List**:
The backing `List` that every **Trip** creates and owns; deleting the trip cascades to the list. Always a real `List` row.
_Avoid_: trip checklist (refers to _contents_, not the list itself)

**Todo**:
A task on a list. Has status, optional due date, optional priority, optional recurrence rule, and links to notes/contexts.
_Avoid_: task, item, entry, todo item

**Subtask**:
A child task under a todo with its own status and title. Has no recurrence, no due date, no contexts.
_Avoid_: checklist item, child todo

**Today List** _(retired — UI removed; `today_list_items` table awaiting schema cleanup)_:
A user's per-day selection of todos (one row per todo per date). No manual ordering; date is part of the key. Backed by `today_list_items`.
_Avoid_: today's tasks, daily list

**Current List**:
A user's sticky "on my plate now" selection of todos with manual ordering. Not date-scoped. Backed by `current_list_items`.
_Avoid_: in-progress list, active list, focus list

**Recurring Todo**:
A todo with a recurrence rule that spawns its next instance when marked complete. Schema column is `todos.recurrence`.
_Avoid_: **Routine** (legacy term, merged into todos by migration `20240101000023`; do not use in new code)

### Cross-cutting

**Context**:
A user-scoped tag attached to todos (e.g. "errands", "work"). Many-to-many with todos via `task_contexts`.
_Avoid_: tag, label, category

**Note**:
A list-scoped rich-text document that can be linked to todos in the same list. Many-to-many with todos via `note_todos`.
_Avoid_: document, comment

**Favorite**:
A user-pinned list or note surfaced on the dashboard. Backed by `dashboard_favorites`.
_Avoid_: pin, bookmark

### Travel

**Trip**:
A travel plan owned by a user; has a destination, dates, transport mode, and a backing **Trip List**.
_Avoid_: journey, travel plan

**Leg**:
A segment of a trip (one origin → destination hop, e.g. "drive to the cottage").
_Avoid_: stage, hop

**Place**:
A specific location within a trip (coordinates, category, date, sort order); ordered within a leg.
_Avoid_: stop, point of interest, POI

### Calendar

**Calendar Token**:
A user's OAuth credentials for Google Calendar, with refresh handling. Backed by `calendar_tokens`.
_Avoid_: oauth token, google credentials

## Relationships

- A **Workspace** has many **Lists**, **Workspace Members**, and **Workspace Invitations**.
- A **List** has many **Todos**; one **List** per workspace per user is the **Inbox List**.
- A **Todo** has many **Subtasks**, many **Contexts** (via `task_contexts`), and many **Notes** (via `note_todos`).
- A **Todo** is _in_ the **Today List** for zero or more dates; a **Todo** is _in_ the user's **Current List** zero or one times.
- A **Trip** owns exactly one **Trip List** (1:1); a **Trip** has many **Legs** and many **Places**.
- A **Note** belongs to exactly one **List** and is reachable from any **Todo** on that list.

## Example dialogue

> **Dev:** "When a user marks a **Recurring Todo** complete, do we delete it from their **Today List**?"
> **Domain expert:** "No — the **Today List** row is keyed by date, so the completed instance stays in today's selection. The spawned next instance is a new **Todo**; it's not automatically added to any **Today List** or **Current List**."

> **Dev:** "If I move a **Todo** between **Lists**, does its **Current List** membership follow?"
> **Domain expert:** "Yes — **Current List** membership is independent of `list_id`. The **Todo** keeps its position in the **Current List** regardless of which **List** it belongs to."

## Flagged ambiguities

- **"Routine" vs "Recurring Todo"** — resolved: use **Recurring Todo**. _Routines_ were a separate table merged into `todos.recurrence` by migration `20240101000023_recurring_todos_merge_routines`. Lingering references in `lib/routines.ts`, `components/due-routines.tsx`, and `ROUTINES_FEATURE.md` are legacy.
- **"List" overloaded** — resolved: **List** refers only to a row in the `lists` table. The three virtual selections — **Today List**, **Current List**, and the dashboard's **Favorites** — are _not_ Lists; they are per-user views over **Todos**.
- **"Trip checklist"** — refers to the _contents_ of a **Trip List**, not a separate entity. Don't introduce a "Checklist" term.
