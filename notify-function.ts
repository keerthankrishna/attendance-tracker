// =====================================================================
// Class Attendance Tracker — `notify` Supabase Edge Function
//
// Sends notification emails to Keerthan + the other person who handles
// the class, when a student is added, updated or deleted, a payment is
// recorded or deleted, or attendance is saved. Every email includes
// "Changed by: <email>" — the Supabase Auth login of the person who
// made the change (the website attaches it from the session).
// Recipients get a log/notification email. NO receipt is sent to
// students/parents — this function only ever mails the NOTIFY_EMAILS list.
//
// Deploy (see SETUP.md section B for the full walkthrough):
//   1. Create a free Resend account and an API key there.
//   2. In Supabase: Edge Functions -> Create function -> name it `notify`,
//      paste this whole file in as the function code, Deploy.
//   3. In the function's Secrets, set:
//        RESEND_API_KEY  = your Resend API key (never put it in code/chat)
//        NOTIFY_EMAILS   = you@example.com, other-handler@example.com
//        MAIL_FROM       = optional, e.g. "Class Tracker <onboarding@resend.dev>"
//                          (onboarding@resend.dev works for testing; for real
//                          use, verify your own domain in Resend and use it)
//   4. In the website's config.js set NOTIFY_ENABLED: true.
// =====================================================================

// deno-lint-ignore-file no-explicit-any
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function money(n: unknown): string {
  const v = Math.round((Number(n) || 0) * 100) / 100;
  return "$" + v.toFixed(2);
}

function escapeHtml(s: unknown): string {
  return String(s == null ? "" : s).replace(/[&<>"']/g, (c: string) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" } as Record<string, string>)[c]
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // The website only calls this with a signed-in user's session token;
    // Supabase verifies that JWT before / inside the function platform.
    // (Verify JWT is ON by default for Edge Functions — leave it on.)

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const recipients = (Deno.env.get("NOTIFY_EMAILS") || "")
      .split(",").map((s: string) => s.trim()).filter(Boolean);
    const from = Deno.env.get("MAIL_FROM") || "Class Tracker <onboarding@resend.dev>";

    if (!resendKey) throw new Error("RESEND_API_KEY secret is not set");
    if (!recipients.length) throw new Error("NOTIFY_EMAILS secret is not set");

    const { type, payload } = await req.json();
    const p = payload || {};

    let subject = "";
    let lines: string[] = [];

    if (type === "class_created") {
      subject = `New class created: ${p.name || p.class_name || ""}`;
      lines = [
        `Class: ${p.name || p.class_name || ""}`,
        p.note ? `Note: ${p.note}` : "",
      ].filter(Boolean);
    } else if (type === "student_added") {
      subject = `New student added: ${p.name || ""}`;
      lines = [
        `Name: ${p.name || ""}`,
        `Pay per class: ${money(p.rate)}`,
        p.joined_date ? `Joined date: ${p.joined_date}` : "",
        p.phone ? `Phone: ${p.phone}` : "",
        p.notes ? `Notes: ${p.notes}` : "",
      ].filter(Boolean);
    } else if (type === "payment_received") {
      subject =
        `Payment received: ${money(p.amount)} from ${p.student_name || ""} ` +
        `(balance ${money(p.balance)})`;
      lines = [
        `Student: ${p.student_name || ""}`,
        `Amount paid: ${money(p.amount)}`,
        p.payment_date ? `Date: ${p.payment_date}` : "",
        p.method ? `Method: ${p.method}` : "",
        `Total paid so far: ${money(p.total_paid)}`,
        `Balance still due: ${money(p.balance)}`,
      ].filter(Boolean);
    } else if (type === "payment_deleted") {
      subject =
        `Payment deleted: ${money(p.amount)} from ${p.student_name || ""} ` +
        `(balance ${money(p.balance)})`;
      lines = [
        `A payment was deleted.`,
        `Student: ${p.student_name || ""}`,
        `Amount removed: ${money(p.amount)}`,
        p.payment_date ? `Payment date was: ${p.payment_date}` : "",
        p.method ? `Method was: ${p.method}` : "",
        `Balance now due: ${money(p.balance)}`,
      ].filter(Boolean);
    } else if (type === "student_updated") {
      subject = `Student updated: ${p.name || ""}`;
      lines = [
        `Name: ${p.name || ""}`,
        (p.prev_name && p.prev_name !== p.name) ? `Name was: ${p.prev_name}` : "",
        `Pay per class: ${money(p.rate)}`,
        (p.prev_rate !== undefined && p.prev_rate !== "" && Number(p.prev_rate) !== Number(p.rate))
          ? `Pay per class was: ${money(p.prev_rate)}` : "",
        p.joined_date ? `Joined date: ${p.joined_date}` : "",
        p.phone ? `Phone: ${p.phone}` : "",
        p.notes ? `Notes: ${p.notes}` : "",
      ].filter(Boolean);
    } else if (type === "attendance_saved") {
      subject =
        `Attendance saved: ${p.class_date || ""} — ` +
        `${p.present_count ?? 0} present, ${p.absent_count ?? 0} absent`;
      lines = [
        `Date: ${p.class_date || ""}`,
        `Present (${p.present_count ?? 0}): ${p.present_names || "—"}`,
        `Absent (${p.absent_count ?? 0}): ${p.absent_names || "—"}`,
      ];
    } else if (type === "student_deleted") {
      subject = `Student deleted: ${p.name || ""}`;
      lines = [
        `A student was deleted (with all their attendance and payments).`,
        `Name: ${p.name || ""}`,
        `Pay per class was: ${money(p.rate)}`,
        p.joined_date ? `Joined date was: ${p.joined_date}` : "",
      ].filter(Boolean);
    } else {
      return new Response(JSON.stringify({ error: "unknown event type" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (p.class_name && type !== "class_created") lines.unshift(`Class: ${p.class_name}`);
    if (p.actor) lines.push(`Changed by: ${p.actor}`);

    const html =
      `<div style="font-family:Arial,sans-serif;color:#000;">` +
      `<h2 style="color:#000;">${escapeHtml(subject)}</h2>` +
      lines.map((l) => `<p style="color:#000;">${escapeHtml(l)}</p>`).join("") +
      `<p style="color:#000;">— Class Attendance Tracker</p></div>`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: recipients,
        subject,
        html,
        text: lines.join("\n"),
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      throw new Error(`Resend error ${res.status}: ${detail}`);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    // The website treats any non-OK response as "(email failed)" and has
    // already saved the student/payment — nothing else depends on this.
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
