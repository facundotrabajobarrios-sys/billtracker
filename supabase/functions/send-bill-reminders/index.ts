import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const resendApiKey = Deno.env.get("RESEND_API_KEY");
const sender = Deno.env.get("MAIL_FROM") ??
  "BillTracker <onboarding@resend.dev>";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Supabase Edge Function secrets are not configured.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

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

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
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
            const response = await fetch("https://api.resend.com/emails", {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${resendApiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                from: sender,
                to: [authUser.user.email],
                subject: `Recordatorio de pago: ${serviceName}`,
                text: message,
                html: `
                  <h2>Recordatorio: ${escapeHtml(serviceName)}</h2>
                  <p>La factura debe ser pagada. Por favor, recuerde pagarla.</p>
                  <ul>
                    <li><strong>Servicio:</strong> ${escapeHtml(serviceName)}</li>
                    <li><strong>Categoría:</strong> ${escapeHtml(categoryName)}</li>
                    <li><strong>Descripción:</strong> ${escapeHtml(description)}</li>
                    <li><strong>Monto:</strong> ${escapeHtml(formattedAmount)}</li>
                    <li><strong>Vencimiento:</strong> ${escapeHtml(dueDate)}</li>
                  </ul>
                `,
              }),
            });

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
