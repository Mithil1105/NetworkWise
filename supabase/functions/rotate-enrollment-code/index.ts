// -----------------------------------------------------------------------------
// rotate-enrollment-code — mints a fresh enrollment code for the caller's org.
// -----------------------------------------------------------------------------
// Called by the admin dashboard's Settings page when the operator presses
// "Rotate code". Admin identity is verified by checking that the caller's
// Supabase Auth JWT maps to a row in `admin_members` for the target org.
//
// Contract
// ~~~~~~~~
// POST /functions/v1/rotate-enrollment-code
// Headers:
//   Authorization: Bearer <supabase-auth-access-token>
// Body:  (empty)
// Response (200):
//   {
//     "enrollment_code": "MSH-7F2K-91QR",
//     "rotated_at":       "<iso8601>"
//   }
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

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

  // 1. Resolve the caller via Supabase Auth.
  const authClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData.user) {
    return jsonResponse({ error: "unauthenticated" }, { status: 401 });
  }
  const userId = userData.user.id;

  // 2. Confirm the caller is an admin for some org, then rotate that org's
  //    code with service_role privileges.
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: member, error: memberErr } = await db
    .from("admin_members")
    .select("organization_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (memberErr) {
    return jsonResponse(
      { error: "db_error", step: "lookup_admin", detail: memberErr.message },
      { status: 500 },
    );
  }
  if (!member) {
    return jsonResponse({ error: "forbidden" }, { status: 403 });
  }

  const { data: rotated, error: rpcErr } = await db.rpc(
    "rotate_organization_enrollment_code",
    { p_organization_id: member.organization_id },
  );

  if (rpcErr) {
    return jsonResponse(
      { error: "db_error", step: "rotate", detail: rpcErr.message },
      { status: 500 },
    );
  }

  // The RPC returns a table (array) — take the first row.
  const row = Array.isArray(rotated) ? rotated[0] : rotated;

  return jsonResponse({
    enrollment_code: row?.enrollment_code ?? null,
    rotated_at: row?.rotated_at ?? new Date().toISOString(),
  });
});
