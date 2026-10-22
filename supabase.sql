-- =====================================================================
-- Class Attendance Tracker — Supabase schema
-- Paste this WHOLE file into: Supabase Dashboard -> SQL Editor -> New query
-- -> Run. It is safe to run on a fresh project AND safe to re-run later
-- (every statement is "if not exists" / "drop policy if exists"), e.g.
-- to add the audit_log table added 2026-10-22. It does NOT contain
-- any keys or passwords.
--
-- App model (v2, multi-class): every tracker is a "class" owned by the
-- user who created it. Row Level Security (RLS) is ON for every table:
-- a signed-in user can only see and change classes they own (and the
-- students / attendance / payments inside them). The ADMIN
-- (kkeerthan@gmail.com) can see and change everything.
-- Anonymous / public visitors can do NOTHING, even though the anon key
-- is visible in the browser — that is what RLS is for.
-- So: keep public sign-ups DISABLED (see SETUP.md) and create login
-- users only for the people who run classes.
-- =====================================================================

-- For gen_random_uuid()
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- classes  (one row per tracker a user creates: "Music", "Art", ...)
-- ---------------------------------------------------------------------
create table if not exists public.classes (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null,
  owner_email text not null,
  name        text not null,
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists classes_owner_id_idx
  on public.classes (owner_id);

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
  class_id    uuid references public.classes (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- Existing installs (table already created without class_id):
alter table public.students
  add column if not exists class_id uuid references public.classes (id) on delete cascade;

create index if not exists students_class_id_idx
  on public.students (class_id);

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

alter table public.audit_log
  add column if not exists class_id uuid;
alter table public.audit_log
  add column if not exists class_name text;

create index if not exists audit_log_created_at_idx
  on public.audit_log (created_at desc);
create index if not exists audit_log_actor_email_idx
  on public.audit_log (actor_email);

-- ---------------------------------------------------------------------
-- Row Level Security: enable on all tables
-- ---------------------------------------------------------------------
alter table public.classes    enable row level security;
alter table public.students   enable row level security;
alter table public.attendance enable row level security;
alter table public.payments   enable row level security;
alter table public.audit_log  enable row level security;

-- ---------------------------------------------------------------------
-- Migration for pre-v2 data: give the admin a default class and move
-- any class-less students into it. Safe to re-run: the insert only
-- happens if the admin owns no class yet, and the update only touches
-- students whose class_id is still null.
-- ---------------------------------------------------------------------
insert into public.classes (owner_id, owner_email, name)
select u.id, u.email, 'My Class'
from auth.users u
where u.email = 'kkeerthan@gmail.com'
  and not exists (select 1 from public.classes c where c.owner_id = u.id);

update public.students s
set class_id = (
  select c.id from public.classes c
  where c.owner_email = 'kkeerthan@gmail.com'
  order by c.created_at asc
  limit 1
)
where s.class_id is null;

-- ---------------------------------------------------------------------
-- Policies (v2): owners see only their own classes/data; the admin
-- (kkeerthan@gmail.com) sees everything. Anon gets nothing.
-- (drop first so re-running this file in the SQL Editor does not error)
-- ---------------------------------------------------------------------
drop policy if exists "authenticated full access" on public.classes;
drop policy if exists "owners and admin full access" on public.classes;
drop policy if exists "owners and admin read" on public.classes;
drop policy if exists "owners and admin create" on public.classes;
drop policy if exists "owners and admin update" on public.classes;
drop policy if exists "admin only delete" on public.classes;
create policy "owners and admin read"
  on public.classes
  for select
  to authenticated
  using (owner_id = auth.uid() or (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com');
create policy "owners and admin create"
  on public.classes
  for insert
  to authenticated
  with check (owner_id = auth.uid() or (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com');
create policy "owners and admin update"
  on public.classes
  for update
  to authenticated
  using (owner_id = auth.uid() or (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com')
  with check (owner_id = auth.uid() or (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com');
-- Deleting a class is ADMIN ONLY (per the owner, 2026-10-22) — regular
-- users cannot delete even their own classes, enforced here in the DB,
-- not just by hiding the button in the app.
create policy "admin only delete"
  on public.classes
  for delete
  to authenticated
  using ((auth.jwt() ->> 'email') = 'kkeerthan@gmail.com');

drop policy if exists "authenticated full access" on public.students;
drop policy if exists "owners and admin full access" on public.students;
create policy "owners and admin full access"
  on public.students
  for all
  to authenticated
  using (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.classes c
      where c.id = class_id and c.owner_id = auth.uid()
    )
  )
  with check (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.classes c
      where c.id = class_id and c.owner_id = auth.uid()
    )
  );

drop policy if exists "authenticated full access" on public.attendance;
drop policy if exists "owners and admin full access" on public.attendance;
create policy "owners and admin full access"
  on public.attendance
  for all
  to authenticated
  using (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.students s
      join public.classes c on c.id = s.class_id
      where s.id = student_id and c.owner_id = auth.uid()
    )
  )
  with check (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.students s
      join public.classes c on c.id = s.class_id
      where s.id = student_id and c.owner_id = auth.uid()
    )
  );

drop policy if exists "authenticated full access" on public.payments;
drop policy if exists "owners and admin full access" on public.payments;
create policy "owners and admin full access"
  on public.payments
  for all
  to authenticated
  using (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.students s
      join public.classes c on c.id = s.class_id
      where s.id = student_id and c.owner_id = auth.uid()
    )
  )
  with check (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or exists (
      select 1 from public.students s
      join public.classes c on c.id = s.class_id
      where s.id = student_id and c.owner_id = auth.uid()
    )
  );

-- Audit log: you can read your own actions, everything inside classes
-- you own, and (admin) everything. You can only write rows as yourself.
drop policy if exists "authenticated full access" on public.audit_log;
drop policy if exists "audit read own, class owners, admin" on public.audit_log;
drop policy if exists "audit insert as self" on public.audit_log;
create policy "audit read own, class owners, admin"
  on public.audit_log
  for select
  to authenticated
  using (
    (auth.jwt() ->> 'email') = 'kkeerthan@gmail.com'
    or actor_email = (auth.jwt() ->> 'email')
    or exists (
      select 1 from public.classes c
      where c.id = class_id and c.owner_id = auth.uid()
    )
  );
create policy "audit insert as self"
  on public.audit_log
  for insert
  to authenticated
  with check (actor_email = (auth.jwt() ->> 'email'));

-- Done. Next steps are in SETUP.md:
--  1. Authentication -> Users: create your own login user.
--  2. Authentication -> Settings: disable public sign-ups.
--  3. Settings -> API: copy Project URL + anon/publishable key into config.js.
