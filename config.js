// Class Attendance Tracker — site configuration.
// Copy the values from YOUR Supabase project: Dashboard -> Settings -> API.
// The anon / publishable key is safe to use in a browser app: the database
// tables use Row Level Security and only signed-in (authenticated) users
// can read or write anything. NEVER put a service_role key in this file.
window.APP_CONFIG = {
  SUPABASE_URL: "PASTE_YOUR_SUPABASE_PROJECT_URL",
  SUPABASE_ANON_KEY: "PASTE_YOUR_SUPABASE_ANON_KEY",

  // Email notifications (optional, later step — see SETUP.md section B).
  // Leave NOTIFY_ENABLED as false until the `notify` Edge Function exists.
  // NOTIFY_EMAILS is documentation for you only; the Edge Function reads
  // the real recipient list from its own NOTIFY_EMAILS secret, not from here.
  NOTIFY_ENABLED: false,
  // Recipient addresses are intentionally NOT stored in this repo file.
  // They live only in the notify Edge Function's NOTIFY_EMAILS secret.
  NOTIFY_EMAILS: []
};
