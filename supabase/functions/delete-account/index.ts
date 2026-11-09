import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleOptions } from "../_shared/admin.ts";

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

Deno.serve(async (request) => {
  const preflight = await handleOptions(request);
  if (preflight) return preflight;
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Missing authorization" }, 401);
    }
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const token = authorization.slice("Bearer ".length);
    const { data: { user }, error } = await admin.auth.getUser(token);
    if (error || !user) {
      return jsonResponse({ error: "Invalid session" }, 401);
    }

    const { data: profile, error: profileError } = await admin
      .from("users")
      .select("avatar_url")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) {
      console.error("Could not read profile avatar:", profileError);
      return jsonResponse({ error: "Could not read profile avatar" }, 500);
    }
    if (typeof profile?.avatar_url === "string") {
      let avatarUrl: URL;
      try {
        avatarUrl = new URL(profile.avatar_url);
      } catch (urlError) {
        console.error("Invalid profile avatar URL:", urlError);
        return jsonResponse({ error: "Invalid profile avatar URL" }, 500);
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
          return jsonResponse({ error: "Invalid profile avatar path" }, 500);
        }
        const pathSegments = objectPath.split("/");
        if (
          pathSegments[0] === user.id &&
          pathSegments.length === 2 &&
          pathSegments.every((segment) =>
            segment && segment !== "." && segment !== ".."
          )
        ) {
          const removed = await admin.storage.from("avatars").remove([
            objectPath,
          ]);
          if (removed.error) {
            console.error("Could not delete profile avatar:", removed.error);
            return jsonResponse({
              error: "Could not delete profile avatar",
              message: removed.error.message,
            }, 500);
          }
        }
      }
    }

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
        return jsonResponse({
          error: `Could not delete ${table}`,
          code: result.error.code,
          message: result.error.message,
        }, 500);
      }
    }
    const deleted = await admin.auth.admin.deleteUser(user.id);
    if (deleted.error) {
      return jsonResponse({ error: deleted.error.message }, 500);
    }
    return jsonResponse({ deleted: true });
  } catch (error) {
    console.error("Unexpected account deletion error:", error);
    return jsonResponse({ error: "Could not delete account" }, 500);
  }
});
