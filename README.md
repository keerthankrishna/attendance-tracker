# Class Attendance Tracker — Supabase version (Option B)

The deployed version of Keerthan's class tracker: a static **GitHub Pages**
front end (`index.html`) backed by a **Supabase** database, so data syncs
across phone and computer. Same design and screens as the tested tracker —
vivid blue header, sky-blue background, bright orange buttons, amber
"Owed to you" card, all text solid black (white only on the blue header).

**👉 Start with [SETUP.md](SETUP.md)** — it walks through Supabase setup,
email notifications, and GitHub Pages publishing, in order.

## Screens

- **Students** — add with a customizable pay-per-class rate ($), phone,
  notes, joined date; edit, pause/resume, delete (cascades to their
  attendance + payments).
- **Attendance** — month calendar (Prev/Next, no date limits). Tap **any**
  date — including past/older dates for backfilling — to open the modal
  and mark each student Present/Absent. Only Present is charged.
- **Summary** — per student: classes attended, total cost
  (attended × rate), total paid, balance due; plus overall charged /
  collected / owed totals.
- **Payments** — student, amount, date, method, note; quick amounts and
  "Pay full balance"; history with delete. Balances auto-update everywhere.

## How it works

- **Login required.** Supabase Auth (email + password). No public sign-up
  screen in the app, and sign-ups should be disabled in Supabase
  (see SETUP.md). Only the owner account can get in.
- **Database:** `students` / `attendance` / `payments` tables, created by
  `supabase.sql`, with Row Level Security on — the browser-visible anon
  key grants nothing on its own; only authenticated users get access.
- **Config:** `config.js` holds only the Supabase Project URL and
  anon/publishable key (placeholders until setup). Never put a
  service_role key, password, or Resend key in this repo.
- **Email notifications (optional):** after a student or payment is
  saved, the app fire-and-forget calls the `notify` Edge Function
  (`notify-function.ts`), which uses Resend to email **Keerthan + the
  other class handler** — never students. A failed email never blocks or
  undoes a save. Setup is SETUP.md section B.
- **Export backup:** the header button downloads all students,
  attendance, and payments as one JSON file.
- **Import:** intentionally **not** included in this Supabase version —
  with a real database as the source of truth, a browser-side
  "replace everything" import is risky. Use the JSON export as a
  portable backup/snapshot; full restores belong in Supabase
  (Dashboard → Database → Backups) or can be scripted from an export
  if ever needed.

## Files

| File | What it is |
|---|---|
| `index.html` | The whole app (loads supabase-js v2 from CDN + `config.js`) |
| `config.js` / `config.example.js` | Your Supabase URL + anon key (+ notify toggle) |
| `supabase.sql` | Schema + RLS policies — paste into Supabase SQL Editor |
| `notify-function.ts` | Resend email Edge Function (later/optional step) |
| `SETUP.md` | Full step-by-step setup, in order |
