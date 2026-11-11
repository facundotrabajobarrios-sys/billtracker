import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = Deno.env.get("RESEND_API_KEY");
const sender = Deno.env.get("MAIL_FROM") ??
  "BillTracker <onboarding@resend.dev>";
const deliveryWindowMs = 30 * 60 * 1000;

type BillReminder = {
  id: string;
  user_id: string;
  due_date: string;
  reminder_at: string;
  reminder_days: number | null;
  amount: number;
  currency: string | null;
  description: string | null;
  reminder_email_enabled: boolean;
  reminder_in_app_enabled: boolean;
  services: { name: string } | null;
  categories: { name: string } | null;
};

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    const entities: Record<string, string> = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return entities[character];
  });
}

function formatAmount(amount: number, currency: string | null): string {
  const code = currency || "PYG";
  try {
    return new Intl.NumberFormat("es-PY", {
      style: "currency",
      currency: code,
      maximumFractionDigits: 0,
    }).format(amount);
  } catch {
    return `${amount} ${code}`;
  }
}

function formatDate(date: string): string {
  return new Intl.DateTimeFormat("es-PY", {
    dateStyle: "long",
    timeZone: "America/Asuncion",
  }).format(new Date(`${date}T12:00:00-03:00`));
}

async function markDelivery(
  billId: string,
  reminderAt: string,
  channel: "email_sent_at" | "notification_created_at",
  deliveredAt: string,
): Promise<boolean> {
  const { error } = await supabase
    .from("bill_reminder_deliveries")
    .update({ [channel]: deliveredAt })
    .eq("bill_id", billId)
    .eq("reminder_at", reminderAt);
  if (!error) return true;
  console.error(`No se pudo registrar el canal ${channel}:`, error.message);
  return false;
}

async function sendEmail(bill: BillReminder, email: string): Promise<Response> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    throw new Error("Falta configurar RESEND_API_KEY para enviar recordatorios.");
  }

  const service = relationName(bill.services) || "Factura";
  const category = relationName(bill.categories) || "Sin categoría";
  const amount = formatAmount(bill.amount, bill.currency);
  const dueDate = formatDate(bill.due_date);
  const description = bill.description?.trim();
  const details = [
    `<tr><td style="padding:8px 12px;color:#526174">Servicio</td><td style="padding:8px 12px;font-weight:600">${escapeHtml(service)}</td></tr>`,
    `<tr><td style="padding:8px 12px;color:#526174">Monto</td><td style="padding:8px 12px;font-weight:600">${escapeHtml(amount)}</td></tr>`,
    `<tr><td style="padding:8px 12px;color:#526174">Vencimiento</td><td style="padding:8px 12px;font-weight:600">${escapeHtml(dueDate)}</td></tr>`,
    `<tr><td style="padding:8px 12px;color:#526174">Categoría</td><td style="padding:8px 12px;font-weight:600">${escapeHtml(category)}</td></tr>`,
    ...(description
      ? [`<tr><td style="padding:8px 12px;color:#526174">Descripción</td><td style="padding:8px 12px">${escapeHtml(description)}</td></tr>`]
      : []),
  ].join("");
  const text = [
    "Hola,",
    "",
    "Te recordamos que tienes una factura pendiente en BillTracker:",
    "",
    `Servicio: ${service}`,
    `Monto: ${amount}`,
    `Vencimiento: ${dueDate}`,
    `Categoría: ${category}`,
    ...(description ? [`Descripción: ${description}`] : []),
    "",
    "Ingresa en BillTracker para consultar o actualizar el estado de tu factura.",
    "Este correo se envió automáticamente; no respondas a este mensaje.",
  ].join("\n");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: sender,
      to: [email],
      subject: `Recordatorio de factura pendiente: ${service}`,
      html: `
        <div style="margin:0;padding:32px 16px;background:#f3f6fa;font-family:Arial,sans-serif;color:#172033">
          <div style="max-width:560px;margin:0 auto;padding:32px;background:#ffffff;border:1px solid #e3e8ef;border-radius:12px">
            <p style="margin:0 0 24px;color:#15803d;font-size:14px;font-weight:700;letter-spacing:.04em">BILLTRACKER</p>
            <h1 style="margin:0 0 16px;font-size:24px;line-height:1.3">Tienes una factura pendiente</h1>
            <p>Hola,</p>
            <p>Te recordamos que tienes una factura pendiente. Aquí tienes sus datos:</p>
            <table role="presentation" style="width:100%;border-collapse:collapse;background:#f8fafc;border-radius:8px">
              <tbody>${details}</tbody>
            </table>
            <p style="margin:24px 0 12px">Ingresa en BillTracker para consultar o actualizar el estado de tu factura.</p>
            <p style="margin:0;color:#64748b;font-size:13px">Este correo se envió automáticamente; no respondas a este mensaje.</p>
            <p style="margin:24px 0 0;color:#64748b;font-size:13px">El equipo de BillTracker</p>
          </div>
        </div>
      `,
      text,
    }),
  });
  return response;
}

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase Edge Function secrets are not configured.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

function relationName(value: unknown): string {
  if (Array.isArray(value)) {
    return relationName(value[0]);
  }
  if (typeof value === "object" && value !== null && "name" in value) {
    const name = value.name;
    return typeof name === "string" ? name : "";
  }
  return "";
}

function hasServiceRole(request: Request): boolean {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return false;

  const encodedClaims = authorization.slice("Bearer ".length).split(".")[1];
  if (!encodedClaims) return false;

  try {
    const base64 = encodedClaims.replace(/-/g, "+").replace(/_/g, "/");
    const paddedBase64 = base64.padEnd(
      Math.ceil(base64.length / 4) * 4,
      "=",
    );
    const bytes = Uint8Array.from(atob(paddedBase64), (character) =>
      character.charCodeAt(0)
    );
    const claims: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return typeof claims === "object" &&
      claims !== null &&
      "role" in claims &&
      claims.role === "service_role";
  } catch {
    return false;
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!hasServiceRole(request)) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const now = new Date();
  const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const { data: bills, error: billsError } = await supabase
    .from("bills")
    .select(`
      id,user_id,due_date,reminder_at,reminder_email_enabled,
      reminder_in_app_enabled,amount,currency,description,
      services(name),categories(name)
    `)
    .eq("status", "pending")
    .or("reminder_email_enabled.eq.true,reminder_in_app_enabled.eq.true")
    .gte("reminder_at", cutoff.toISOString())
    .lte("reminder_at", now.toISOString());

  if (billsError) {
    console.error("Could not load due reminders:", billsError.message);
    return Response.json({ error: "Could not load due reminders." }, { status: 500 });
  }

  let emailSent = 0;
  let inAppCreated = 0;
  const deliveryErrors: string[] = [];

  for (const bill of bills ?? []) {
    if (!bill.reminder_at) continue;
    const reminderAt = new Date(bill.reminder_at).toISOString();
    let { data: delivery, error: deliveryError } = await supabase
      .from("bill_reminder_deliveries")
      .select("email_sent_at,notification_created_at")
      .eq("bill_id", bill.id)
      .eq("reminder_at", reminderAt)
      .maybeSingle();

    if (deliveryError) {
      console.error("Could not load reminder delivery:", deliveryError.message);
      deliveryErrors.push("delivery-lookup");
      continue;
    }

    if (!delivery) {
      const inserted = await supabase
        .from("bill_reminder_deliveries")
        .upsert(
          { bill_id: bill.id, reminder_at: reminderAt },
          { onConflict: "bill_id,reminder_at", ignoreDuplicates: true },
        );
      if (inserted.error) {
        console.error("Could not register reminder delivery:", inserted.error.message);
        deliveryErrors.push("delivery-register");
        continue;
      }

      const lookup = await supabase
        .from("bill_reminder_deliveries")
        .select("email_sent_at,notification_created_at")
        .eq("bill_id", bill.id)
        .eq("reminder_at", reminderAt)
        .single();
      if (lookup.error) {
        console.error("Could not read reminder delivery:", lookup.error.message);
        deliveryErrors.push("delivery-read");
        continue;
      }
      delivery = lookup.data;
    }

    const serviceName = relationName(bill.services) || "Factura";
    const categoryName = relationName(bill.categories) || "Sin categoría";
    const description = bill.description || "Sin descripción";
    const dueDate = new Date(bill.due_date).toLocaleDateString("es-PY", {
      timeZone: "UTC",
    });
    const formattedAmount = new Intl.NumberFormat("es-PY", {
      style: "currency",
      currency: bill.currency || "PYG",
      maximumFractionDigits: 0,
    }).format(Number(bill.amount));
    const message =
      `Recordatorio: la factura ${serviceName} debe ser pagada. ` +
      `Servicio: ${serviceName}. Categoría: ${categoryName}. ` +
      `Descripción: ${description}. Monto: ${formattedAmount}. ` +
      `Vencimiento: ${dueDate}.`;

    if (bill.reminder_email_enabled && !delivery.email_sent_at) {
      if (!resendApiKey) {
        console.error("RESEND_API_KEY is not configured.");
        deliveryErrors.push("email-config");
      } else {
        const { data: authUser, error: userError } =
          await supabase.auth.admin.getUserById(bill.user_id);

        if (userError || !authUser.user?.email) {
          console.error(
            "Could not resolve reminder recipient:",
            userError?.message ?? "Account has no email.",
          );
          deliveryErrors.push("email-recipient");
        } else {
          try {
            const response = await sendEmail(bill, authUser.user.email);

            if (!response.ok) {
              const details = await response.text();
              console.error("Resend rejected reminder:", response.status, details);
              deliveryErrors.push("email-provider");
            } else {
              const updatedDelivery = await supabase
                .from("bill_reminder_deliveries")
                .update({ email_sent_at: now.toISOString() })
                .eq("bill_id", bill.id)
                .eq("reminder_at", reminderAt);
              if (updatedDelivery.error) {
                console.error(
                  "Could not record email delivery:",
                  updatedDelivery.error.message,
                );
                deliveryErrors.push("email-record");
              } else {
                emailSent++;
              }
            }
          } catch (error) {
            console.error("Could not contact the email provider:", error);
            deliveryErrors.push("email-network");
          }
        }
      }
    }

    if (bill.reminder_in_app_enabled && !delivery.notification_created_at) {
      const existingNotification = await supabase
        .from("notifications")
        .select("id")
        .eq("bill_id", bill.id)
        .eq("scheduled_at", reminderAt)
        .eq("type", "reminder")
        .maybeSingle();

      if (existingNotification.error) {
        console.error(
          "Could not check existing in-app reminder:",
          existingNotification.error.message,
        );
        deliveryErrors.push("in-app-insert");
      } else {
        if (!existingNotification.data) {
          const notification = await supabase.from("notifications").insert({
            user_id: bill.user_id,
            bill_id: bill.id,
            title: `Recordatorio de pago: ${serviceName}`,
            message,
            type: "reminder",
            scheduled_at: reminderAt,
            sent_at: now.toISOString(),
          });
          if (notification.error) {
            console.error(
              "Could not create in-app reminder:",
              notification.error.message,
            );
            deliveryErrors.push("in-app-insert");
            continue;
          }
        }

        const updatedDelivery = await supabase
          .from("bill_reminder_deliveries")
          .update({ notification_created_at: now.toISOString() })
          .eq("bill_id", bill.id)
          .eq("reminder_at", reminderAt);
        if (updatedDelivery.error) {
          console.error(
            "Could not record in-app delivery:",
            updatedDelivery.error.message,
          );
          deliveryErrors.push("in-app-record");
        } else {
          if (!existingNotification.data) inAppCreated++;
        }
      }
    }
  }

  return Response.json(
    { emailSent, inAppCreated, errors: deliveryErrors },
    { status: deliveryErrors.length === 0 ? 200 : 500 },
  );
});
