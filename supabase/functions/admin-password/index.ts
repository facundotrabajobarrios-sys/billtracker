import { corsHeaders, handleOptions, jsonResponse, requireAdmin } from "../_shared/admin.ts";

Deno.serve(async (request) => {
  const options = await handleOptions(request);
  if (options) return options;
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const { client, userId, mustChangePassword } = await requireAdmin(request, true);
    if (!mustChangePassword) {
      return jsonResponse({ error: "The initial password has already been changed" }, 409);
    }
    const body = await request.json();
    const password = body?.password;
    if (typeof password !== "string" || password.length < 12) {
      return jsonResponse({ error: "Password must be at least 12 characters" }, 400);
    }

    const { error: passwordError } = await client.auth.admin.updateUserById(userId, {
      password,
    });
    if (passwordError) {
      console.error("Could not update administrator password:", passwordError);
      return jsonResponse({ error: "Could not update administrator password" }, 500);
    }

    const { error: roleError } = await client
      .from("admin_roles")
      .update({ must_change_password: false })
      .eq("user_id", userId);
    if (roleError) {
      console.error("Could not complete administrator password change:", roleError);
      return jsonResponse({ error: "Password changed, but account setup is incomplete" }, 500);
    }

    const { error: auditError } = await client.from("admin_audit_logs").insert({
      admin_user_id: userId,
      action: "initial_password_changed",
    });
    if (auditError) console.error("Could not record password change:", auditError);

    return jsonResponse({ changed: true });
  } catch (error) {
    if (error instanceof Response) {
      return jsonResponse({ error: await error.text() }, error.status);
    }
    console.error("Administrator password change failed:", error);
    return jsonResponse({ error: "Could not change administrator password" }, 500);
  }
});
