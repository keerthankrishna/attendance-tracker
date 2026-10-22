# Setup — Class Attendance Tracker (GitHub Pages + Supabase)

Follow these steps **in order**: A) Supabase database + login, B) email
notifications (optional, can be done later), C) GitHub Pages website.

> **What you (Keerthan) need to provide, and nothing more:**
> 1. Your **GitHub connection** (so the files can be pushed to your repo).
> 2. Your **Supabase Project URL** (from Settings → API).
> 3. Your Supabase **anon / publishable key** (from Settings → API — this
>    one is safe to share and safe to put in `config.js`).
> 4. **Your login email** (the one your tracker account will use).
> 5. The **2 notification email addresses** (yours + the other person who
>    handles the class) — only needed for step B.
>
> **Never share these in chat:** your Supabase *service_role* key, your
> login *password*, or your Resend API key. Passwords are typed by you
> into Supabase/your own accounts; API keys go into Supabase *secrets*
> (step B) — never into code and never into this repo.

The tracker starts **empty** — no old data is migrated. You can backfill
older classes afterwards: the Attendance calendar lets you tap **any**
date, including past dates, and move month-to-month with Prev / Next.

---

## A. Supabase — database and login

You said you already have a Supabase account. Either open your existing
project or create a new free one named e.g. `class-attendance-tracker`.

1. **Create/open the project** at supabase.com → your project. Wait until
   it finishes provisioning.
2. **Create the tables:** left sidebar → **SQL Editor** → **New query**.
   Open the `supabase.sql` file from this folder, copy the **whole** file,
   paste it in, and click **Run**. You should see "Success. No rows
   returned". This creates the `students`, `attendance`, and `payments`
   tables with Row Level Security turned on, so only signed-in users can
   read or write anything.
3. **Create your login user:** left sidebar → **Authentication → Users**
   → **Add user → Create new user**. Enter **your login email** and a
   password *you choose* (type it directly into Supabase — don't send it
   to anyone), and tick **Auto Confirm User** if shown.
4. **Disable public sign-ups** (important — this is a private, single-owner
   app): **Authentication → Settings** (a.k.a. Auth configuration) →
   turn **OFF** "Allow new users to sign up". The app itself has no
   sign-up screen; this makes sure nobody else can create an account.
5. **Copy the two config values:** **Settings → API**. Note:
   - **Project URL** — looks like `https://abcdefghijklmnop.supabase.co`
   - **anon / publishable key** — a long key labelled `anon` / `publishable`.
     (Do **not** copy the `service_role` / secret key anywhere.)
   Paste both into **`config.js`** in this folder, replacing the
   `PASTE_…` placeholders. The placeholders are how the website knows to
   show its "Setup needed" screen — once real values are in, that screen
   goes away and the sign-in screen appears.

## B. Email notifications — via Resend + a Supabase Edge Function (later step)

Goal: whenever you **add a new student** or **record a payment**, an email
goes to **you and the other person who handles the class**. No receipt is
sent to students/parents — these are notification/log emails for the two
of you only.

The website already calls the function after every successful student /
payment save (function name: `notify`). Until this step is done, that call
is simply skipped — saving works exactly the same, with no error shown.

1. **Create a free Resend account** at resend.com (free tier is roughly
   3,000 emails/month, 100/day — far more than this class needs) and
   create an **API key** there. Keep it for step 3 — it goes into a
   Supabase *secret*, never into code, config, or chat.
   - Testing works right away with Resend's `onboarding@resend.dev`
     sender. For long-term use, verify your own domain in Resend
     (Domains → Add) so emails don't land in spam, and use an address on
     that domain as the sender in step 3.
2. **Create the Edge Function:** Supabase → **Edge Functions** →
   **Create a new function** → name it exactly **`notify`** → paste in the
   **whole contents of `notify-function.ts`** from this folder → **Deploy**.
   (Leave "Verify JWT" ON, which is the default.)
3. **Set the function's secrets:** Edge Functions → `notify` → **Secrets**
   (or Project Settings → Edge Functions → Secrets). Add:
   - `RESEND_API_KEY` = the API key from step 1
   - `NOTIFY_EMAILS` = the **2 notification email addresses**,
     comma-separated, e.g. `you@example.com, other-handler@example.com`
   - `MAIL_FROM` = *(optional)* e.g. `Class Tracker <onboarding@resend.dev>`
4. **Turn notifications on in the website:** in `config.js`, set
   `NOTIFY_ENABLED: true` (the `NOTIFY_EMAILS` list in config.js is only a
   note for you — the function reads its recipients from the secret in
   step 3). Upload the updated `config.js` to GitHub (step C).
5. **Test it:** sign in to the tracker, add a test student. Both
   recipients should get "New student added: …". Record a test payment —
   both should get "Payment received: $… from … (balance $…)".
   If a save succeeds but the email doesn't arrive, the tracker shows a
   subtle "Saved ✓ (email failed)" note and **the save still counts** —
   check the function's logs under Edge Functions → `notify` → Logs.

## C. GitHub — publish the website free with GitHub Pages

1. **Create the repo:** on github.com, **New repository**, name it e.g.
   `class-attendance-tracker`, set it **Public** (GitHub Pages on a free
   account serves from public repos). The repo contains only code — your
   student/payment data lives in Supabase, not in these files, and the
   tables are locked behind login by Row Level Security.
2. **Push/upload these files** to the repo root:
   - `index.html`
   - `config.js` (with *your* Project URL + anon key from step A5)
   - `README.md`, `SETUP.md` (documentation — optional for the app itself)
   - `config.example.js`, `supabase.sql`, `notify-function.ts`
     (reference/setup files — also fine to include; none of them contain
     any real keys)
3. **Turn on Pages:** repo → **Settings → Pages** → Build and deployment
   → Source: **Deploy from a branch** → Branch: **`main`**, folder
   **`/ (root)`** → **Save**.
4. **Wait a minute**, reload that Pages settings page, and open the live
   URL it shows, typically:
   `https://<your-username>.github.io/<your-repo>/`
5. **Test the live site:**
   - You should see the **Sign in** screen (not the "Setup needed"
     screen — if you see that, `config.js` on GitHub still has the
     `PASTE_…` placeholders).
   - Sign in with the user from step A3.
   - Add a student, go to Attendance, tap a **past date**, mark them
     Present, Save — the Summary should charge one class.
   - Record a payment — the Summary balance should drop, and (if step B
     is done) both notification emails should arrive.
   - Open the same URL on your phone, sign in, and check the same data is
     there — that's the Supabase sync working.
6. **Bookmark the URL** on your phone and computer. To update the app
   later, replace the files in the repo and push again; Pages redeploys
   automatically.

---

### Troubleshooting quick list

- **"Setup needed" screen** → `config.js` in the repo still has
  placeholders. Fix A5 and re-upload `config.js`.
- **Sign-in fails** → the user doesn't exist or the password is wrong
  (A3), or the Project URL/key in `config.js` point at a different project.
- **Signed in but lists are empty / errors** → `supabase.sql` was not run
  in *this* project (A2), or sign-ups/RLS state differs. Re-run the SQL.
- **Data visible but emails never arrive** → step B: check
  `NOTIFY_ENABLED`, the function name is exactly `notify`, the secrets are
  set, and the function logs in Supabase.
