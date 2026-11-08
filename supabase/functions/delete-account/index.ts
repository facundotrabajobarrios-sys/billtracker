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

  const { data: profile, error: profileError } = await admin
    .from("users")
    .select("avatar_url")
    .eq("id", user.id)
    .maybeSingle();
  if (profileError) {
    console.error("Could not read profile avatar:", profileError);
    return Response.json({ error: "Could not read profile avatar" }, { status: 500 });
  }
  if (typeof profile?.avatar_url === "string") {
    let avatarUrl: URL;
    try {
      avatarUrl = new URL(profile.avatar_url);
    } catch (urlError) {
      console.error("Invalid profile avatar URL:", urlError);
      return Response.json({ error: "Invalid profile avatar URL" }, { status: 500 });
    }
    const avatarPrefix = "/storage/v1/object/public/avatars/";
    if (avatarUrl.pathname.startsWith(avatarPrefix)) {
      let objectPath: string;
      try {
        objectPath = decodeURIComponent(
          avatarUrl.pathname.slice(avatarPrefix.length),
        );
      } catch (pathError) {
        console.error("Invalid profile avatar path:", pathError);
        return Response.json({ error: "Invalid profile avatar path" }, { status: 500 });
      }
      const pathSegments = objectPath.split("/");
      if (
        pathSegments[0] === user.id &&
        pathSegments.length === 2 &&
        pathSegments.every((segment) => segment && segment !== "." && segment !== "..")
      ) {
        const removed = await admin.storage.from("avatars").remove([objectPath]);
        if (removed.error) {
          console.error("Could not delete profile avatar:", removed.error);
          return Response.json({
            error: "Could not delete profile avatar",
            message: removed.error.message,
          }, { status: 500 });
        }
      }
    }
  }

  // Remove dependent application rows before deleting the Auth identity.
  for (
    const table of [
      "notification_preferences",
      "notifications",
      "gamifications",
      "bills",
      "services",
      "users",
    ]
  ) {
    const column = table === "users" ? "id" : "user_id";
    const result = await admin.from(table).delete().eq(column, user.id);
    if (result.error) {
      console.error(`Could not delete ${table}:`, result.error);
      return Response.json({
        error: `Could not delete ${table}`,
        code: result.error.code,
        message: result.error.message,
      }, { status: 500 });
    }
  }
  const deleted = await admin.auth.admin.deleteUser(user.id);
  if (deleted.error) return Response.json({ error: deleted.error.message }, { status: 500 });
  return Response.json({ deleted: true });
});
