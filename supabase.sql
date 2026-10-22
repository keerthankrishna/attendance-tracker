-- =====================================================================
-- Class Attendance Tracker — Supabase schema
-- Paste this WHOLE file into: Supabase Dashboard -> SQL Editor -> New query
-- -> Run. It is safe to run on a fresh project AND safe to re-run later
-- (every statement is "if not exists" / "drop policy if exists"), e.g.
-- to add the audit_log table added 2026-10-22. It does NOT contain
-- any keys or passwords.
--
-- App model: single owner. Row Level Security (RLS) is ON for every table,
-- and the only policies allow signed-in (authenticated) users to do
-- everything. Anonymous / public visitors can do NOTHING, even though the
-- anon key is visible in the browser — that is what RLS is for.
-- So: keep public sign-ups DISABLED (see SETUP.md) and create only your
-- own login user in Authentication -> Users.
-- =====================================================================

-- For gen_random_uuid()
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- students
-- ---------------------------------------------------------------------
create table if not exists public.students (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  rate        numeric(10,2) not null default 0 check (rate >= 0),
  phone       text,
  notes       text,
  joined_date date,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- attendance  (one row per student per class date)
-- present = true  -> Present (charged)
-- present = false -> Absent  (marked, never charged)
-- no row          -> not marked for that date
-- ---------------------------------------------------------------------
create table if not exists public.attendance (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students (id) on delete cascade,
  class_date date not null,
  present    boolean not null default false,
  created_at timestamptz not null default now(),
  unique (student_id, class_date)
);

create index if not exists attendance_class_date_idx
  on public.attendance (class_date);
create index if not exists attendance_student_id_idx
  on public.attendance (student_id);

-- ---------------------------------------------------------------------
-- payments
-- ---------------------------------------------------------------------
create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.students (id) on delete cascade,
  amount       numeric(10,2) not null check (amount > 0),
  payment_date date not null default current_date,
  method       text,
  note         text,
  created_at   timestamptz not null default now()
);

create index if not exists payments_student_id_idx
  on public.payments (student_id);

-- ---------------------------------------------------------------------
-- audit_log  (one row per action taken in the app: who + what + when)
-- Written by the website on every add / update / delete / attendance
-- save / sign-in / sign-out / backup export. Read on the app's Log
-- screen, filterable by date and by user (actor_email).
-- ---------------------------------------------------------------------
create table if not exists public.audit_log (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  actor_email text,
  event_type  text not null,
  entity      text,
  summary     text,
  details     jsonb
);

create index if not exists audit_log_created_at_idx
  on public.audit_log (created_at desc);
create index if not exists audit_log_actor_email_idx
  on public.audit_log (actor_email);

-- ---------------------------------------------------------------------
-- Row Level Security: enable on all tables
-- ---------------------------------------------------------------------
alter table public.students   enable row level security;
alter table public.attendance enable row level security;
alter table public.payments   enable row level security;
alter table public.audit_log  enable row level security;

-- Policies: authenticated users get full access; anon gets nothing.
-- (drop first so re-running this file in the SQL Editor does not error)
drop policy if exists "authenticated full access" on public.students;
create policy "authenticated full access"
  on public.students
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "authenticated full access" on public.attendance;
create policy "authenticated full access"
  on public.attendance
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "authenticated full access" on public.payments;
create policy "authenticated full access"
  on public.payments
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "authenticated full access" on public.audit_log;
create policy "authenticated full access"
  on public.audit_log
  for all
  to authenticated
  using (true)
  with check (true);

-- Done. Next steps are in SETUP.md:
--  1. Authentication -> Users: create your own login user.
--  2. Authentication -> Settings: disable public sign-ups.
--  3. Settings -> API: copy Project URL + anon/publishable key into config.js.
