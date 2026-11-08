import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": [
    "authorization",
    "apikey",
    "content-type",
    "x-admin-bootstrap-token",
    "x-client-info",
    "x-supabase-api-version",
    "x-supabase-client-platform",
    "x-supabase-client-platform-version",
    "x-supabase-client-runtime",
    "x-supabase-client-runtime-version",
  ].join(", "),
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Supabase service configuration is missing");
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function requireAdmin(
  request: Request,
  allowPasswordChange = false,
): Promise<{ client: SupabaseClient; userId: string; mustChangePassword: boolean }> {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    throw new Response("Missing authorization", { status: 401 });
  }

  const client = serviceClient();
  const { data: { user }, error } = await client.auth.getUser(
    authorization.slice("Bearer ".length),
  );
  if (error || !user) throw new Response("Invalid session", { status: 401 });

  const { data: role, error: roleError } = await client
    .from("admin_roles")
    .select("must_change_password")
    .eq("user_id", user.id)
    .maybeSingle();
  if (roleError) {
    console.error("Could not verify administrator role:", roleError);
    throw new Response("Could not verify administrator role", { status: 500 });
  }
  if (!role) throw new Response("Administrator access required", { status: 403 });

  const mustChangePassword = role.must_change_password === true;
  if (mustChangePassword && !allowPasswordChange) {
    throw new Response("Administrator password change required", { status: 403 });
  }

  return { client, userId: user.id, mustChangePassword };
}

export async function handleOptions(request: Request): Promise<Response | null> {
  return request.method === "OPTIONS"
    ? new Response("ok", { headers: corsHeaders })
    : null;
}
