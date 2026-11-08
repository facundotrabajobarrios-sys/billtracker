import {
  handleOptions,
  jsonResponse,
  requireAdmin,
} from "../_shared/admin.ts";

type AdminContext = Awaited<ReturnType<typeof requireAdmin>>;

function cleanSearch(value: unknown): string {
  return typeof value === "string"
    ? value.trim().replace(/[^a-zA-Z0-9 @._+-]/g, "").slice(0, 80)
    : "";
}

function validId(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

async function writeAudit(
  context: AdminContext,
  action: string,
  values: { targetUserId?: string; targetBillId?: string; metadata?: Record<string, unknown> } = {},
) {
  const { error } = await context.client.from("admin_audit_logs").insert({
    admin_user_id: context.userId,
    action,
    target_user_id: values.targetUserId ?? null,
    target_bill_id: values.targetBillId ?? null,
    metadata: values.metadata ?? {},
  });
  if (error) throw error;
}

async function listAuthUsers(context: AdminContext) {
  const users = [];
  for (let page = 1; ; page++) {
    const { data, error } = await context.client.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    users.push(...data.users);
    if (data.users.length < 1000) break;
  }
  return users;
}

async function dashboard(context: AdminContext) {
  const client = context.client;
  const [users, bills, pending, paid, overdue, recent, authUsers, auditCount] =
    await Promise.all([
      client.from("users").select("id", { count: "exact", head: true }),
      client.from("bills").select("id", { count: "exact", head: true }),
      client.from("bills").select("id", { count: "exact", head: true }).eq("status", "pending"),
      client.from("bills").select("id", { count: "exact", head: true }).eq("status", "paid"),
      client.from("bills").select("id", { count: "exact", head: true }).eq("status", "overdue"),
      client.from("users")
        .select("id,email,name,created_at,avatar_url")
        .order("created_at", { ascending: false })
        .limit(5),
      listAuthUsers(context),
      client.from("admin_audit_logs").select("id", { count: "exact", head: true }),
    ]);

  for (const result of [users, bills, pending, paid, overdue, recent, auditCount]) {
    if (result.error) throw result.error;
  }
  const activeCutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
  const activeUsers = authUsers.filter((user) =>
    (!user.banned_until || Date.parse(user.banned_until) <= Date.now()) &&
    user.last_sign_in_at != null &&
    Date.parse(user.last_sign_in_at) >= activeCutoff
  ).length;

  return {
    totalUsers: users.count ?? 0,
    activeUsers,
    recentUsers: recent.data ?? [],
    totalBills: bills.count ?? 0,
    pendingBills: pending.count ?? 0,
    paidBills: paid.count ?? 0,
    overdueBills: overdue.count ?? 0,
    adminActions: auditCount.count ?? 0,
  };
}

async function usersList(context: AdminContext, body: Record<string, unknown>) {
  const page = Math.max(0, Number.isInteger(body.page) ? Number(body.page) : 0);
  const pageSize = Math.min(50, Math.max(1, Number(body.pageSize) || 25));
  const search = cleanSearch(body.search);
  const sortBy = ["created_at", "name", "email"].includes(String(body.sortBy))
    ? String(body.sortBy)
    : "created_at";
  let query = context.client
    .from("users")
    .select("id,email,name,created_at,avatar_url", { count: "exact" });
  if (search) query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%`);
  const { data, count, error } = await query
    .order(sortBy, { ascending: body.ascending === true, nullsFirst: false })
    .range(page * pageSize, page * pageSize + pageSize - 1);
  if (error) throw error;

  const authUsers = await listAuthUsers(context);
  const authById = new Map(authUsers.map((user) => [user.id, user]));
  return {
    rows: (data ?? []).map((profile) => {
      const authUser = authById.get(profile.id);
      return {
        ...profile,
        email: authUser?.email ?? profile.email,
        lastSignInAt: authUser?.last_sign_in_at ?? null,
        isActive: !authUser?.banned_until ||
          Date.parse(authUser.banned_until) <= Date.now(),
        isAdmin: false,
      };
    }),
    total: count ?? 0,
    page,
    pageSize,
  };
}

async function userDetails(context: AdminContext, body: Record<string, unknown>) {
  if (!validId(body.userId)) return jsonResponse({ error: "Invalid user ID" }, 400);
  const { data: profile, error: profileError } = await context.client
    .from("users")
    .select("id,email,name,created_at,avatar_url,level,points")
    .eq("id", body.userId)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile) return jsonResponse({ error: "User not found" }, 404);
  const [bills, authUsers] = await Promise.all([
    context.client.from("bills")
      .select("id,status,amount,due_date,created_at", { count: "exact" })
      .eq("user_id", body.userId)
      .order("created_at", { ascending: false })
      .limit(100),
    listAuthUsers(context),
  ]);
  if (bills.error) throw bills.error;
  const authUser = authUsers.find((user) => user.id === body.userId);
  return {
    user: {
      ...profile,
      email: authUser?.email ?? profile.email,
      lastSignInAt: authUser?.last_sign_in_at ?? null,
      isActive: !authUser?.banned_until ||
        Date.parse(authUser.banned_until) <= Date.now(),
    },
    bills: bills.data ?? [],
    billsTotal: bills.count ?? 0,
  };
}

async function billsList(context: AdminContext, body: Record<string, unknown>) {
  const page = Math.max(0, Number.isInteger(body.page) ? Number(body.page) : 0);
  const pageSize = Math.min(50, Math.max(1, Number(body.pageSize) || 25));
  const search = cleanSearch(body.search);
  const status = ["pending", "paid", "overdue"].includes(String(body.status))
    ? String(body.status)
    : "";
  let query = context.client
    .from("bills")
    .select("id,user_id,service_id,category_id,amount,currency,due_date,paid_date,status,description,created_at", { count: "exact" });
  if (status) query = query.eq("status", status);
  if (search) {
    const filters = [`description.ilike.%${search}%`];
    if (validId(search)) {
      filters.push(`user_id.eq.${search}`);
    } else {
      const { data: matchingUsers, error: matchingUsersError } = await context.client
        .from("users")
        .select("id")
        .or(`name.ilike.%${search}%,email.ilike.%${search}%`)
        .limit(100);
      if (matchingUsersError) throw matchingUsersError;
      const ids = (matchingUsers ?? []).map((user) => user.id);
      if (ids.length > 0) filters.push(`user_id.in.(${ids.join(",")})`);
    }
    query = query.or(filters.join(","));
  }
  const { data, count, error } = await query
    .order("due_date", { ascending: true })
    .range(page * pageSize, page * pageSize + pageSize - 1);
  if (error) throw error;

  const userIds = [...new Set((data ?? []).map((bill) => bill.user_id))];
  const serviceIds = [...new Set((data ?? []).map((bill) => bill.service_id))];
  const categoryIds = [...new Set((data ?? []).map((bill) => bill.category_id))];
  const [profiles, services, categories] = await Promise.all([
    userIds.length
      ? context.client.from("users").select("id,name,email").in("id", userIds)
      : Promise.resolve({ data: [], error: null }),
    serviceIds.length
      ? context.client.from("services").select("id,name").in("id", serviceIds)
      : Promise.resolve({ data: [], error: null }),
    categoryIds.length
      ? context.client.from("categories").select("id,name").in("id", categoryIds)
      : Promise.resolve({ data: [], error: null }),
  ]);
  for (const result of [profiles, services, categories]) {
    if (result.error) throw result.error;
  }
  const profilesById = new Map((profiles.data ?? []).map((item) => [item.id, item]));
  const servicesById = new Map((services.data ?? []).map((item) => [item.id, item.name]));
  const categoriesById = new Map((categories.data ?? []).map((item) => [item.id, item.name]));
  return {
    rows: (data ?? []).map((bill) => ({
      ...bill,
      user: profilesById.get(bill.user_id) ?? null,
      serviceName: servicesById.get(bill.service_id) ?? "Servicio",
      categoryName: categoriesById.get(bill.category_id) ?? "Sin categoría",
    })),
    total: count ?? 0,
    page,
    pageSize,
  };
}

async function updateUser(context: AdminContext, body: Record<string, unknown>) {
  if (!validId(body.userId)) return jsonResponse({ error: "Invalid user ID" }, 400);
  const name = typeof body.name === "string" ? body.name.trim() : "";
  if (!name || name.length > 100) {
    return jsonResponse({ error: "Name must contain 1 to 100 characters" }, 400);
  }
  const { data, error } = await context.client.from("users")
    .update({ name })
    .eq("id", body.userId)
    .select("id,name")
    .maybeSingle();
  if (error) throw error;
  if (!data) return jsonResponse({ error: "User not found" }, 404);
  await writeAudit(context, "user_name_updated", {
    targetUserId: body.userId,
    metadata: { name },
  });
  return { updated: true, user: data };
}

async function setUserActive(context: AdminContext, body: Record<string, unknown>) {
  if (!validId(body.userId) || typeof body.isActive !== "boolean") {
    return jsonResponse({ error: "Invalid account status request" }, 400);
  }
  if (body.userId === context.userId) {
    return jsonResponse({ error: "You cannot disable your own account" }, 400);
  }
  const { data: adminTarget, error: roleError } = await context.client
    .from("admin_roles")
    .select("user_id")
    .eq("user_id", body.userId)
    .maybeSingle();
  if (roleError) throw roleError;
  if (adminTarget) return jsonResponse({ error: "Administrator accounts cannot be disabled here" }, 400);

  const { error } = await context.client.auth.admin.updateUserById(body.userId, {
    ban_duration: body.isActive ? "none" : "876000h",
  });
  if (error) throw error;
  await writeAudit(context, body.isActive ? "user_enabled" : "user_disabled", {
    targetUserId: body.userId,
  });
  return { updated: true };
}

async function deleteUser(context: AdminContext, body: Record<string, unknown>) {
  if (!validId(body.userId)) return jsonResponse({ error: "Invalid user ID" }, 400);
  if (body.userId === context.userId) {
    return jsonResponse({ error: "You cannot delete your own account" }, 400);
  }
  const { data: adminTarget, error: roleError } = await context.client
    .from("admin_roles")
    .select("user_id")
    .eq("user_id", body.userId)
    .maybeSingle();
  if (roleError) throw roleError;
  if (adminTarget) return jsonResponse({ error: "Administrator accounts cannot be deleted here" }, 400);

  await writeAudit(context, "user_deletion_requested", {
    targetUserId: body.userId,
  });

  const { data: cleanup, error: cleanupError } = await context.client.rpc(
    "admin_delete_user_data",
    {
      p_target_user_id: body.userId,
      p_admin_user_id: context.userId,
    },
  );
  if (cleanupError) {
    console.error("Could not transactionally clean administrator target:", cleanupError);
    throw cleanupError;
  }

  const authUserExists = async () =>
    (await listAuthUsers(context)).some((user) => user.id === body.userId);
  if (await authUserExists()) {
    const { error: authDeleteError } = await context.client.auth.admin.deleteUser(
      body.userId,
    );
    if (authDeleteError && await authUserExists()) {
      throw new Error(
        `BillTracker data was cleaned, but the Supabase Auth account could not be deleted: ${authDeleteError.message}`,
      );
    }
  }

  try {
    await writeAudit(context, "user_deleted", {
      targetUserId: body.userId,
      metadata: cleanup as Record<string, unknown>,
    });
  } catch (auditError) {
    console.error("User was deleted but completion audit could not be written:", auditError);
  }
  return { deleted: true, cleanup };
}

async function updateBill(context: AdminContext, body: Record<string, unknown>) {
  if (!validId(body.billId)) return jsonResponse({ error: "Invalid bill ID" }, 400);
  const updates: Record<string, unknown> = {};
  if (body.amount !== undefined) {
    const amount = Number(body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return jsonResponse({ error: "Amount must be greater than zero" }, 400);
    }
    updates.amount = amount;
  }
  if (body.dueDate !== undefined) {
    if (typeof body.dueDate !== "string" || Number.isNaN(Date.parse(body.dueDate))) {
      return jsonResponse({ error: "Invalid due date" }, 400);
    }
    updates.due_date = body.dueDate;
  }
  if (body.status !== undefined) {
    if (!["pending", "paid", "overdue"].includes(String(body.status))) {
      return jsonResponse({ error: "Invalid bill status" }, 400);
    }
    updates.status = body.status;
    updates.paid_date = body.status === "paid"
      ? new Date().toISOString()
      : null;
  }
  if (body.description !== undefined) {
    if (body.description !== null && typeof body.description !== "string") {
      return jsonResponse({ error: "Invalid bill description" }, 400);
    }
    if (typeof body.description === "string" && body.description.length > 1000) {
      return jsonResponse({ error: "Description is too long" }, 400);
    }
    updates.description = body.description;
  }
  if (Object.keys(updates).length === 0) {
    return jsonResponse({ error: "No editable bill fields provided" }, 400);
  }
  updates.updated_at = new Date().toISOString();
  const { data, error } = await context.client.from("bills")
    .update(updates)
    .eq("id", body.billId)
    .select("id,user_id,status,amount,due_date")
    .maybeSingle();
  if (error) throw error;
  if (!data) return jsonResponse({ error: "Bill not found" }, 404);
  await writeAudit(context, "bill_updated", {
    targetUserId: data.user_id,
    targetBillId: body.billId,
    metadata: { changedFields: Object.keys(updates) },
  });
  return { updated: true, bill: data };
}

async function auditList(context: AdminContext) {
  const { data, error } = await context.client.from("admin_audit_logs")
    .select("id,admin_user_id,action,target_user_id,target_bill_id,metadata,created_at")
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return { rows: data ?? [] };
}

async function getSettings(context: AdminContext) {
  const { data, error } = await context.client.from("admin_settings")
    .select("value,updated_at")
    .eq("key", "public_announcement")
    .single();
  if (error) throw error;
  return { announcement: data.value, updatedAt: data.updated_at };
}

async function updateSettings(context: AdminContext, body: Record<string, unknown>) {
  const announcement = typeof body.announcement === "string"
    ? body.announcement.trim()
    : "";
  if (announcement.length > 500) {
    return jsonResponse({ error: "Announcement must be 500 characters or fewer" }, 400);
  }
  const { error } = await context.client.from("admin_settings").upsert({
    key: "public_announcement",
    value: announcement,
    updated_by: context.userId,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
  await writeAudit(context, "system_announcement_updated", {
    metadata: { enabled: announcement.length > 0 },
  });
  return { updated: true, announcement };
}

function respond(result: unknown): Response {
  return result instanceof Response ? result : jsonResponse(result);
}

function errorResponse(error: unknown): Response {
  const details = error && typeof error === "object"
    ? error as { message?: unknown; code?: unknown; details?: unknown }
    : null;
  const message = typeof details?.message === "string"
    ? details.message
    : String(error);
  return jsonResponse({
    error: "Administrator request failed",
    message,
    ...(typeof details?.code === "string" ? { code: details.code } : {}),
    ...(typeof details?.details === "string" && details.details
      ? { details: details.details }
      : {}),
  }, 500);
}

Deno.serve(async (request) => {
  const options = await handleOptions(request);
  if (options) return options;
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const context = await requireAdmin(request);
    const body = await request.json() as Record<string, unknown>;
    switch (body.action) {
      case "dashboard":
        return respond(await dashboard(context));
      case "users":
        return respond(await usersList(context, body));
      case "user_details":
        return respond(await userDetails(context, body));
      case "bills":
        return respond(await billsList(context, body));
      case "update_user":
        return respond(await updateUser(context, body));
      case "set_user_active":
        return respond(await setUserActive(context, body));
      case "delete_user":
        return respond(await deleteUser(context, body));
      case "update_bill":
        return respond(await updateBill(context, body));
      case "audit":
        return respond(await auditList(context));
      case "get_settings":
        return respond(await getSettings(context));
      case "update_settings":
        return respond(await updateSettings(context, body));
      default:
        return jsonResponse({ error: "Unknown administrator action" }, 400);
    }
  } catch (error) {
    if (error instanceof Response) {
      return jsonResponse({ error: await error.text() }, error.status);
    }
    console.error("Administrator API request failed:", error);
    return errorResponse(error);
  }
});
