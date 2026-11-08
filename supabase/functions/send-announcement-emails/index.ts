import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = Deno.env.get("RESEND_API_KEY");
const sender = Deno.env.get("MAIL_FROM") ??
  "BillTracker <onboarding@resend.dev>";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase Edge Function secrets are not configured.");
}

const client = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[character]!);
}

async function deliver(row: {
  id: string;
  user_id: string;
  title: string;
  message: string;
}) {
  try {
    if (!resendApiKey) throw new Error("RESEND_API_KEY is not configured.");
    const { data: userResult, error: userError } = await client.auth.admin
      .getUserById(row.user_id);
    if (userError) throw userError;
    const email = userResult.user.email;
    if (!email) throw new Error("Recipient has no email address.");

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": `billtracker-announcement-${row.id}`,
      },
      body: JSON.stringify({
        from: sender,
        to: [email],
        subject: `BillTracker: ${row.title}`,
        html: `<div style="font-family:Arial,Helvetica,sans-serif;max-width:560px;margin:24px auto;color:#1f2933"><div style="background:#16834a;color:#fff;padding:22px;border-radius:14px 14px 0 0;text-align:center;font-size:22px;font-weight:bold">BillTracker</div><div style="padding:28px;border:1px solid #e5e7eb;border-top:0;border-radius:0 0 14px 14px"><h1 style="font-size:22px">${escapeHtml(row.title)}</h1><p style="font-size:16px;line-height:1.6;white-space:pre-wrap">${escapeHtml(row.message)}</p><p style="font-size:12px;color:#6b7280">Comunicado publicado por BillTracker.</p></div></div>`,
        text: `${row.title}\n\n${row.message}\n\nComunicado publicado por BillTracker.`,
      }),
    });
    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(`Resend returned ${response.status}: ${responseText.slice(0, 1000)}`);
    }

    let providerId: string | null = null;
    try {
      providerId = (JSON.parse(responseText) as { id?: string }).id ?? null;
    } catch {
      providerId = null;
    }
    const { error: updateError } = await client
      .from("announcement_email_deliveries")
      .update({
        status: "sent",
        sent_at: new Date().toISOString(),
        provider_id: providerId,
        error: null,
      })
      .eq("id", row.id);
    if (updateError) throw updateError;
  } catch (error) {
    const { error: updateError } = await client
      .from("announcement_email_deliveries")
      .update({
        status: "failed",
        error: String(error).slice(0, 1000),
      })
      .eq("id", row.id);
    if (updateError) console.error("Could not save announcement email error:", updateError);
    console.error(`Announcement email delivery failed (${row.id}):`, error);
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }
  const authorization = request.headers.get("Authorization");
  if (authorization !== `Bearer ${serviceRoleKey}`) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { data, error } = await client.rpc("claim_announcement_email_deliveries");
  if (error) {
    console.error("Could not claim announcement email deliveries:", error);
    return Response.json({ error: "Could not claim email deliveries" }, { status: 500 });
  }

  const deliveries = (data ?? []) as Array<{
    id: string;
    user_id: string;
    title: string;
    message: string;
  }>;
  await Promise.all(deliveries.map(deliver));
  return Response.json({ processed: deliveries.length });
});
