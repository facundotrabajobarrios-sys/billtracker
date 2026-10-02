import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const sender = Deno.env.get("MAIL_FROM") ??
    "BillTracker <onboarding@resend.dev>";
  if (!supabaseUrl || !serviceRoleKey || !resendApiKey) {
    console.error("Test email function is missing required configuration.");
    return jsonResponse({ error: "El servicio de correo no está configurado." }, 503);
  }

  const token = authorization.slice("Bearer ".length);
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user?.email) {
    return jsonResponse({ error: "La sesión no es válida." }, 401);
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: sender,
        to: [data.user.email],
        subject: "Prueba de notificación - BillTracker",
        html: "<p>Las notificaciones por correo de BillTracker están funcionando.</p>",
        text: "Las notificaciones por correo de BillTracker están funcionando.",
      }),
    });

    if (!response.ok) {
      console.error("Resend rejected the test email:", response.status);
      return jsonResponse(
        { error: "El proveedor de correo rechazó el envío de prueba." },
        502,
      );
    }

    return jsonResponse({ sent: true });
  } catch (error) {
    console.error("Could not send the test email:", error);
    return jsonResponse({ error: "No se pudo contactar al proveedor de correo." }, 502);
  }
});
