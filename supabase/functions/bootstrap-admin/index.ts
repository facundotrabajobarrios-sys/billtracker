import { corsHeaders, jsonResponse, serviceClient } from "../_shared/admin.ts";

const ADMIN_EMAIL = "admin@billtracker.invalid";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const expectedToken = Deno.env.get("ADMIN_BOOTSTRAP_TOKEN");
  const password = Deno.env.get("ADMIN_INITIAL_PASSWORD");
  if (!expectedToken || !password) {
    console.error("Administrator bootstrap secrets are not configured");
    return jsonResponse({ error: "Administrator bootstrap is not configured" }, 503);
  }
  if (request.headers.get("x-admin-bootstrap-token") !== expectedToken) {
    return jsonResponse({ error: "Invalid bootstrap token" }, 401);
  }
  if (password.length < 8) {
    return jsonResponse({ error: "Initial password must be at least 8 characters" }, 500);
  }

  const client = serviceClient();
  const { error: reservationError } = await client
    .from("admin_bootstrap_state")
    .insert({ id: 1, status: "pending" });
  if (reservationError) {
    if (reservationError.code === "23505") {
      return jsonResponse({ error: "Administrator bootstrap has already been used" }, 409);
    }
    console.error("Could not reserve administrator bootstrap:", reservationError);
    return jsonResponse({ error: "Could not reserve administrator bootstrap" }, 500);
  }

  let createdUserId: string | null = null;
  try {
    const { data, error } = await client.auth.admin.createUser({
      email: ADMIN_EMAIL,
      password,
      email_confirm: true,
      user_metadata: { name: "Administrador" },
    });
    if (error || !data.user) throw error ?? new Error("Auth did not return the new user");
    createdUserId = data.user.id;

    const { error: profileError } = await client.from("users").upsert({
      id: data.user.id,
      email: ADMIN_EMAIL,
      name: "Administrador",
      level: 0,
      points: 0,
    });
    if (profileError) throw profileError;

    const { error: roleError } = await client.from("admin_roles").insert({
      user_id: data.user.id,
      must_change_password: true,
    });
    if (roleError) throw roleError;

    const { error: completeError } = await client
      .from("admin_bootstrap_state")
      .update({
        status: "completed",
        admin_user_id: data.user.id,
        completed_at: new Date().toISOString(),
      })
      .eq("id", 1);
    if (completeError) throw completeError;

    return jsonResponse({
      created: true,
      username: "admin",
      email: ADMIN_EMAIL,
      mustChangePassword: true,
    });
  } catch (error) {
    console.error("Administrator bootstrap failed:", error);
    if (createdUserId) {
      const { error: cleanupError } = await client.auth.admin.deleteUser(createdUserId);
      if (cleanupError) {
        console.error("Could not clean up incomplete administrator:", cleanupError);
      }
    }
    const { error: reservationCleanupError } = await client
      .from("admin_bootstrap_state")
      .delete()
      .eq("id", 1)
      .eq("status", "pending");
    if (reservationCleanupError) {
      console.error("Could not release bootstrap reservation:", reservationCleanupError);
    }
    return jsonResponse({ error: "Could not create administrator account" }, 500);
  }
});
