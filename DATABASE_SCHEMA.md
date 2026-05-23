# Database Schema Documentation

This document describes the database schema for Familator, including all tables, relationships, and security policies.

## Overview

The database schema consists of several main tables:

- `profiles` - User profile information
- `lists` - Todo lists within workspaces
- `todos` - Todo items within lists
- `subtasks` - Subtasks belonging to todos
- `today_list_items` - Daily "Today List" assignments
- `routines` - Recurring tasks with automatic scheduling

## Tables

### profiles

Extends `auth.users` with additional user profile information.

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `user_id` (uuid, unique, foreign key → auth.users.id) - References auth user
- `display_name` (text, nullable) - User's display name
- `avatar_url` (text, nullable) - URL to user's avatar image
- `created_at` (timestamptz) - Creation timestamp
- `updated_at` (timestamptz) - Last update timestamp

**Indexes:**

- Primary key on `id`
- Unique constraint on `user_id`
- Index on `user_id`

**RLS Policies:**

- Users can SELECT their own profile
- Users can UPDATE their own profile
- Users can INSERT their own profile (typically via trigger)

**Triggers:**

- Automatically creates profile when a new user signs up
- Automatically updates `updated_at` on profile updates

---

### lists

Todo lists that can be personal or shared with other users.

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `owner_id` (uuid, foreign key → auth.users.id) - List owner
- `name` (text, not null) - List name
- `description` (text, nullable) - List description
- `is_shared` (boolean, default false) - Whether list is shared
- `created_at` (timestamptz) - Creation timestamp
- `updated_at` (timestamptz) - Last update timestamp

**Indexes:**

- Primary key on `id`
- Index on `owner_id`
- Index on `is_shared`
- Index on `created_at`

**RLS Policies:**

- Users can SELECT lists they own
- Users can SELECT shared lists they are members of
- Users can INSERT their own lists
- Users can UPDATE lists they own or are editors of
- Users can DELETE lists they own

**Triggers:**

- Automatically updates `updated_at` on list updates

---

### todos

Todo items within lists.

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `list_id` (bigint, foreign key → lists.id) - Parent list
- `title` (text, not null) - Todo title
- `description` (text, nullable) - Todo description
- `status` (text, default 'pending') - Status: 'pending' or 'completed'
- `priority` (text, nullable) - Priority: 'low', 'medium', or 'high'
- `due_date` (timestamptz, nullable) - Due date
- `created_at` (timestamptz) - Creation timestamp
- `updated_at` (timestamptz) - Last update timestamp
- `completed_at` (timestamptz, nullable) - Completion timestamp

**Constraints:**

- Check constraint on `status` (must be 'pending' or 'completed')
- Check constraint on `priority` (must be 'low', 'medium', or 'high')

**Indexes:**

- Primary key on `id`
- Index on `list_id`
- Index on `status`
- Index on `due_date`
- Index on `created_at`

**RLS Policies:**

- Users can SELECT todos in lists they own or are members of
- Users can INSERT todos in lists they own or are editors of
- Users can UPDATE todos in lists they own or are editors of
- Users can DELETE todos in lists they own or are editors of

**Triggers:**

- Automatically updates `updated_at` on todo updates
- Automatically sets `completed_at` when status changes to 'completed'
- Clears `completed_at` when status changes from 'completed'

---

### subtasks

Subtasks belonging to todos.

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `todo_id` (bigint, foreign key → todos.id) - Parent todo
- `title` (text, not null) - Subtask title
- `status` (text, default 'pending') - Status: 'pending' or 'completed'
- `created_at` (timestamptz) - Creation timestamp
- `updated_at` (timestamptz) - Last update timestamp
- `completed_at` (timestamptz, nullable) - Completion timestamp

**Constraints:**

- Check constraint on `status` (must be 'pending' or 'completed')

**Indexes:**

- Primary key on `id`
- Index on `todo_id`
- Index on `status`

**RLS Policies:**

- Users can SELECT subtasks of todos they have access to
- Users can INSERT subtasks for todos they can edit
- Users can UPDATE subtasks for todos they can edit
- Users can DELETE subtasks for todos they can edit

**Triggers:**

- Automatically updates `updated_at` on subtask updates
- Automatically sets `completed_at` when status changes to 'completed'
- Clears `completed_at` when status changes from 'completed'

---

### today_list_items

Links todos to users' daily "Today List". Items are date-specific.

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `user_id` (uuid, foreign key → auth.users.id) - The user
- `todo_id` (bigint, foreign key → todos.id) - The todo
- `date` (date, default CURRENT_DATE) - The date for this today list item
- `created_at` (timestamptz) - Creation timestamp

**Constraints:**

- Unique constraint on (`user_id`, `todo_id`, `date`)

**Indexes:**

- Primary key on `id`
- Index on `user_id`
- Index on `todo_id`
- Index on `date`
- Composite index on (`user_id`, `date`)

**RLS Policies:**

- Users can SELECT their own today list items
- Users can INSERT their own today list items (for todos they have access to)
- Users can UPDATE their own today list items
- Users can DELETE their own today list items

---

### routines

Recurring tasks that repeat on a regular schedule (e.g., take out trash every week, haircut every 3 months).

**Columns:**

- `id` (bigint, primary key) - Auto-generated ID
- `user_id` (uuid, foreign key → auth.users.id) - The user who owns this routine
- `title` (text, not null) - Routine title
- `description` (text, nullable) - Routine description
- `interval_type` (text, not null) - Type of interval: 'daily', 'weekly', 'monthly', or 'yearly'
- `interval_value` (integer, not null, default 1) - Number of intervals (e.g., 1 for every week, 3 for every 3 months)
- `last_completed_at` (timestamptz, nullable) - Timestamp when the routine was last completed
- `next_due_at` (timestamptz, not null) - Calculated timestamp for when the routine is next due
- `is_active` (boolean, not null, default true) - Whether the routine is currently active or paused
- `created_at` (timestamptz) - Creation timestamp
- `updated_at` (timestamptz) - Last update timestamp

**Constraints:**

- Check constraint on `interval_type` (must be 'daily', 'weekly', 'monthly', or 'yearly')
- Check constraint on `interval_value` (must be greater than 0)

**Indexes:**

- Primary key on `id`
- Index on `user_id`
- Index on `next_due_at`
- Index on `is_active`
- Composite index on (`user_id`, `next_due_at`) where `is_active = true`

**RLS Policies:**

- Users can SELECT their own routines
- Users can INSERT their own routines
- Users can UPDATE their own routines
- Users can DELETE their own routines

**Triggers:**

- Automatically updates `updated_at` on routine updates
- Automatically calculates `next_due_at` when `last_completed_at` is updated, based on `interval_type` and `interval_value`

---

## Relationships

```
auth.users
  ├── profiles (1:1 via user_id)
  ├── lists (1:many via owner_id)
  ├── today_list_items (1:many via user_id)
  └── routines (1:many via user_id)

lists
  └── todos (1:many via list_id)

todos
  ├── subtasks (1:many via todo_id)
  └── today_list_items (1:many via todo_id)
```

## Security

All tables have Row Level Security (RLS) enabled. Policies ensure that:

- Users can only access their own data
- Access to lists and all related data is governed by workspace membership
- Foreign key relationships maintain data integrity

## Applying Migrations

### Using Supabase CLI (Recommended)

1. Install Supabase CLI:

   ```bash
   npm install -g supabase
   ```

2. Link to your Supabase project:

   ```bash
   supabase link --project-ref your-project-ref
   ```

3. Apply migrations:
   ```bash
   supabase db push
   ```

### Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run each migration file in order (20240101000001 through 20240101000006)
4. Verify migrations were applied successfully

### Migration Order

Migrations must be applied in this order:

1. `20240101000001_create_profiles.sql`
2. `20240101000002_create_lists.sql`
3. `20240101000004_create_todos.sql`
4. `20240101000005_create_subtasks.sql`
5. `20240101000006_create_today_list_items.sql`
6. `20240101000007_add_user_search_function.sql`
7. `20240101000008_add_today_list_cleanup_function.sql`
8. `20240101000009_create_calendar_tokens.sql`
9. `20240101000010_add_calendar_event_id_to_todos.sql`
10. `20240101000011_add_performance_indexes.sql`
11. `20240101000012_add_selected_calendars_to_calendar_tokens.sql`
12. `20240101000013_create_routines.sql`

## Testing

Run database schema tests:

```bash
npm test -- __tests__/database/schema.test.ts
npm test -- __tests__/database/rls-policies.test.ts
```

## TypeScript Types

TypeScript types for the database schema are available in `lib/database/types.ts`. These types are generated to match the database schema and provide type safety when working with Supabase queries.
