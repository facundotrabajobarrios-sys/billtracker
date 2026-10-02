import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Faltan las variables de entorno de Supabase.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);
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

async function sendEmail(bill: BillReminder, email: string): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    throw new Error("Falta configurar RESEND_API_KEY para enviar recordatorios.");
  }

  const service = bill.services?.name ?? "Factura";
  const category = bill.categories?.name ?? "Sin categoría";
  const amount = formatAmount(bill.amount, bill.currency);
  const dueDate = formatDate(bill.due_date);
  const description = bill.description?.trim();
  const details = [
    `<li><strong>Servicio:</strong> ${escapeHtml(service)}</li>`,
    `<li><strong>Monto:</strong> ${escapeHtml(amount)}</li>`,
    `<li><strong>Vencimiento:</strong> ${escapeHtml(dueDate)}</li>`,
    `<li><strong>Categoría:</strong> ${escapeHtml(category)}</li>`,
    ...(description
      ? [`<li><strong>Descripción:</strong> ${escapeHtml(description)}</li>`]
      : []),
  ].join("");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: sender,
      to: [email],
      subject: `Recordatorio de pago: ${service}`,
      html: `<p>Recuerda que tienes un pago próximo:</p><ul>${details}</ul>`,
      text: [
        "Recuerda que tienes un pago próximo:",
        `Servicio: ${service}`,
        `Monto: ${amount}`,
        `Vencimiento: ${dueDate}`,
        `Categoría: ${category}`,
        ...(description ? [`Descripción: ${description}`] : []),
      ].join("\n"),
    }),
  });
  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Resend devolvió ${response.status}: ${details}`);
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const now = new Date();
  const windowStart = new Date(now.getTime() - deliveryWindowMs);
  const { data: bills, error } = await supabase
    .from("bills")
    .select(
      "id,user_id,due_date,reminder_at,reminder_days,amount,currency," +
        "description,reminder_email_enabled,reminder_in_app_enabled," +
        "services(name),categories(name)",
    )
    .eq("status", "pending")
    .or("reminder_email_enabled.eq.true,reminder_in_app_enabled.eq.true")
    .gte("reminder_at", windowStart.toISOString())
    .lte("reminder_at", now.toISOString());
  if (error) {
    console.error("No se pudieron consultar los recordatorios:", error.message);
    return Response.json({ error: "No se pudieron consultar los recordatorios." }, {
      status: 500,
    });
  }

  let emailsSent = 0;
  let notificationsCreated = 0;
  for (const bill of (bills ?? []) as BillReminder[]) {
    const reminderAt = new Date(bill.reminder_at).toISOString();
    const { error: insertError } = await supabase
      .from("bill_reminder_deliveries")
      .upsert(
        { bill_id: bill.id, reminder_at: reminderAt },
        { onConflict: "bill_id,reminder_at", ignoreDuplicates: true },
      );
    if (insertError) {
      console.error("No se pudo iniciar el registro de entrega:", insertError.message);
      continue;
    }

    const { data: delivery, error: deliveryError } = await supabase
      .from("bill_reminder_deliveries")
      .select("email_sent_at,notification_created_at")
      .eq("bill_id", bill.id)
      .eq("reminder_at", reminderAt)
      .single();
    if (deliveryError || !delivery) {
      console.error("No se pudo leer el registro de entrega:", deliveryError?.message);
      continue;
    }

    if (bill.reminder_email_enabled && !delivery.email_sent_at) {
      const { data: authUser, error: userError } =
        await supabase.auth.admin.getUserById(bill.user_id);
      if (userError) {
        console.error("No se pudo obtener el destinatario:", userError.message);
        continue;
      }

      if (authUser.user?.email) {
        try {
          await sendEmail(bill, authUser.user.email);
          emailsSent++;
        } catch (emailError) {
          console.error(
            `No se pudo enviar correo para la factura ${bill.id}:`,
            emailError,
          );
          continue;
        }
      }

      if (
        !await markDelivery(
          bill.id,
          reminderAt,
          "email_sent_at",
          now.toISOString(),
        )
      ) continue;
    } else if (!bill.reminder_email_enabled && !delivery.email_sent_at) {
      if (
        !await markDelivery(
          bill.id,
          reminderAt,
          "email_sent_at",
          now.toISOString(),
        )
      ) continue;
    }

    if (bill.reminder_in_app_enabled && !delivery.notification_created_at) {
      const service = bill.services?.name ?? "Factura";
      const amount = formatAmount(bill.amount, bill.currency);
      const dueDate = formatDate(bill.due_date);
      const details = [
        `Monto: ${amount}`,
        `Vencimiento: ${dueDate}`,
        `Categoría: ${bill.categories?.name ?? "Sin categoría"}`,
        ...(bill.description?.trim()
          ? [`Descripción: ${bill.description.trim()}`]
          : []),
      ];
      const { error: notificationError } = await supabase
        .from("notifications")
        .insert({
          user_id: bill.user_id,
          bill_id: bill.id,
          title: `Recordatorio de pago: ${service}`,
          message: details.join(" · "),
          type: "reminder",
          scheduled_at: reminderAt,
          sent_at: now.toISOString(),
        });
      if (notificationError) {
        console.error(
          `No se pudo crear notificación para factura ${bill.id}:`,
          notificationError.message,
        );
        continue;
      }
      notificationsCreated++;
      if (
        !await markDelivery(
          bill.id,
          reminderAt,
          "notification_created_at",
          now.toISOString(),
        )
      ) continue;
    } else if (!bill.reminder_in_app_enabled &&
      !delivery.notification_created_at) {
      await markDelivery(
        bill.id,
        reminderAt,
        "notification_created_at",
        now.toISOString(),
      );
    }
  }

  return Response.json({ emailsSent, notificationsCreated });
});
