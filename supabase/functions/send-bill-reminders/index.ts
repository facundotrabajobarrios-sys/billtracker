import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const apiKey = Deno.env.get("RESEND_API_KEY")!;
const sender = Deno.env.get("MAIL_FROM") ?? "BillTracker <onboarding@resend.dev>";

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const now = new Date();
  const horizon = new Date(now);
  horizon.setDate(horizon.getDate() + 10);
  const { data: bills, error } = await supabase
    .from("bills")
    .select("id,user_id,due_date,reminder_days,reminder_time_minutes,services(name)")
    .eq("status", "pending")
    .gte("due_date", now.toISOString())
    .lte("due_date", horizon.toISOString());
  if (error) return Response.json({ error: error.message }, { status: 500 });

  let sent = 0;
  for (const bill of bills ?? []) {
    const due = new Date(bill.due_date);
    const reminder = new Date(due);
    reminder.setDate(reminder.getDate() - (bill.reminder_days ?? 3));
    const minutes = bill.reminder_time_minutes ?? 540;
    reminder.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
    if (Math.abs(now.getTime() - reminder.getTime()) > 30 * 60 * 1000) continue;

    const { data: preferences } = await supabase
      .from("notification_preferences")
      .select("email_enabled,due_date_reminders")
      .eq("user_id", bill.user_id)
      .maybeSingle();
    if (preferences && (!preferences.email_enabled || !preferences.due_date_reminders)) continue;
    const { data: authUser } = await supabase.auth.admin.getUserById(bill.user_id);
    if (!authUser.user?.email) continue;

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: sender,
        to: [authUser.user.email],
        subject: "Recordatorio de vencimiento - BillTracker",
        html: `<p>Tu factura vence el ${due.toLocaleDateString("es-PY")}.</p>`,
      }),
    });
    if (response.ok) sent++;
  }
  return Response.json({ sent });
});
