import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return new Response("Missing authorization", { status: 401 });
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const token = authorization.replace("Bearer ", "");
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return new Response("Invalid session", { status: 401 });

  // Delete application data before deleting the Auth identity.
  for (const table of ["notification_preferences", "bills", "services", "users"]) {
    const column = table === "bills" || table === "services" ? "user_id" : "id";
    const result = await admin.from(table).delete().eq(column, user.id);
    if (result.error) {
      return Response.json({ error: `Could not delete ${table}` }, { status: 500 });
    }
  }
  const deleted = await admin.auth.admin.deleteUser(user.id);
  if (deleted.error) return Response.json({ error: deleted.error.message }, { status: 500 });
  return Response.json({ deleted: true });
});
