// -----------------------------------------------------------------------------
// invite-admin — creates a Supabase Auth user + admin_members row so the
// new admin can sign in to the NetworkWise dashboard.
// -----------------------------------------------------------------------------
// Only existing admins of the same organisation can invoke this. The
// caller is identified via their Supabase Auth JWT (the `authorization`
// header); new-user creation runs under the service role.
//
// Contract
// ~~~~~~~~
// POST /functions/v1/invite-admin
// Headers:
//   Authorization: Bearer <supabase-auth-access-token>
// Body:
//   {
//     "email":     "new-admin@mistryandshah.com",
//     "password":  "<initial password, min 8 chars>",
//     "full_name": "Optional display name",
//     "role":      "admin" | "owner"   // defaults to "admin"
//   }
// Response (200):
//   {
//     "user_id":         "<uuid>",
//     "organization_id": "<uuid>",
//     "email":           "<as submitted>",
//     "role":            "admin" | "owner"
//   }
// Response (409):
//   { "error": "already_admin" }        — email already has a row
//   { "error": "email_in_use" }         — auth user exists, not yet admin
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

interface InvitePayload {
  email?: string;
  password?: string;
  full_name?: string;
  role?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  const authHeader = req.headers.get("authorization") ??
    req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "unauthenticated" }, { status: 401 });
  }

  // -------- 1. Who is calling? --------
  const authClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData.user) {
    return jsonResponse({ error: "unauthenticated" }, { status: 401 });
  }
  const callerId = userData.user.id;

  // -------- 2. Parse + validate payload --------
  let payload: InvitePayload;
  try {
    payload = (await req.json()) as InvitePayload;
  } catch (_) {
    return jsonResponse({ error: "invalid_json" }, { status: 400 });
  }
  const email = (payload.email ?? "").trim().toLowerCase();
  const password = payload.password ?? "";
  const fullName = (payload.full_name ?? "").trim();
  const role = (payload.role ?? "admin").trim().toLowerCase();

  if (!email || !email.includes("@")) {
    return jsonResponse({ error: "invalid_email" }, { status: 400 });
  }
  if (password.length < 8) {
    return jsonResponse({ error: "password_too_short" }, { status: 400 });
  }
  if (role !== "admin" && role !== "owner") {
    return jsonResponse({ error: "invalid_role" }, { status: 400 });
  }

  // -------- 3. Resolve caller's org via admin_members --------
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: caller, error: callerErr } = await db
    .from("admin_members")
    .select("organization_id, role")
    .eq("user_id", callerId)
    .maybeSingle();

  if (callerErr) {
    return jsonResponse(
      { error: "db_error", step: "lookup_caller", detail: callerErr.message },
      { status: 500 },
    );
  }
  if (!caller) {
    return jsonResponse({ error: "forbidden" }, { status: 403 });
  }
  const orgId = caller.organization_id as string;

  // Only an `owner` can mint another `owner`.
  if (role === "owner" && caller.role !== "owner") {
    return jsonResponse({ error: "owner_required" }, { status: 403 });
  }

  // -------- 4. Check for an existing auth user --------
  // The Admin API exposes getUserByEmail-style lookups via listUsers
  // with a filter; here we page-scan because the v2 client lacks a
  // direct lookup. Limit to 1000 — practical for our tenant size.
  const { data: listed, error: listErr } = await db.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (listErr) {
    return jsonResponse(
      { error: "auth_error", step: "list_users", detail: listErr.message },
      { status: 500 },
    );
  }
  const existing = listed.users.find(
    (u) => (u.email ?? "").toLowerCase() === email,
  );

  let userId: string;
  if (existing) {
    userId = existing.id;
    // Is this user already an admin in THIS org?
    const { data: existingMember } = await db
      .from("admin_members")
      .select("organization_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (existingMember) {
      return jsonResponse({ error: "already_admin" }, { status: 409 });
    }
  } else {
    // -------- 5. Create the auth user --------
    const { data: created, error: createErr } = await db.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: fullName ? { full_name: fullName } : undefined,
      });
    if (createErr || !created.user) {
      return jsonResponse(
        {
          error: "auth_error",
          step: "create_user",
          detail: createErr?.message ?? "unknown",
        },
        { status: 500 },
      );
    }
    userId = created.user.id;
  }

  // -------- 6. Insert admin_members row --------
  const { error: insertErr } = await db.from("admin_members").insert({
    user_id: userId,
    organization_id: orgId,
    role,
    full_name: fullName.length > 0 ? fullName : null,
  });
  if (insertErr) {
    return jsonResponse(
      { error: "db_error", step: "insert_admin", detail: insertErr.message },
      { status: 500 },
    );
  }

  return jsonResponse({
    user_id: userId,
    organization_id: orgId,
    email,
    role,
  });
});
