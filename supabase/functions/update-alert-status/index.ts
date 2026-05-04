// -----------------------------------------------------------------------------
// update-alert-status  —  transition an alert between open / acknowledged / resolved.
// -----------------------------------------------------------------------------
// POST /functions/v1/update-alert-status
// Body:
//   {
//     "device_id":           "<uuid>",       // required — owning device
//     "registration_secret": "<opaque>",     // required — device secret
//     "alert_id":            "<uuid>",       // required — alert to update
//     "action":              "acknowledge" | "resolve" | "reopen",
//     "actor":               "operator@org"  // optional — free-text label
//   }
//
// Transitions allowed:
//   open          — acknowledge → acknowledged
//                 — resolve     → resolved
//   acknowledged  — resolve     → resolved
//                 — reopen      → open
//   resolved      — reopen      → open
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type AlertStatus = "open" | "acknowledged" | "resolved";
type Action = "acknowledge" | "resolve" | "reopen";

interface UpdatePayload {
  device_id: string;
  registration_secret: string;
  alert_id: string;
  action: Action;
  actor?: string;
}

function nextStatus(current: AlertStatus, action: Action): AlertStatus | null {
  if (action === "acknowledge" && current === "open") return "acknowledged";
  if (action === "resolve" && (current === "open" || current === "acknowledged")) return "resolved";
  if (action === "reopen" && (current === "acknowledged" || current === "resolved")) return "open";
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  let body: Partial<UpdatePayload>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, { status: 400 });
  }

  if (!body.device_id || !body.registration_secret || !body.alert_id || !body.action) {
    return jsonResponse(
      {
        error: "validation_failed",
        message: "device_id, registration_secret, alert_id and action are required",
      },
      { status: 400 },
    );
  }
  if (!["acknowledge", "resolve", "reopen"].includes(body.action)) {
    return jsonResponse(
      { error: "validation_failed", message: "action must be acknowledge|resolve|reopen" },
      { status: 400 },
    );
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Authenticate the device.
  const { data: device, error: devErr } = await db
    .from("devices")
    .select("id, organization_id, registration_secret")
    .eq("id", body.device_id)
    .maybeSingle();

  if (devErr) {
    return jsonResponse(
      { error: "db_error", detail: devErr.message }, { status: 500 },
    );
  }
  if (!device || device.registration_secret !== body.registration_secret) {
    return jsonResponse({ error: "forbidden" }, { status: 403 });
  }

  // 2. Load alert and check it belongs to this device/organization.
  const { data: alert, error: alErr } = await db
    .from("alerts")
    .select("id, device_id, organization_id, status")
    .eq("id", body.alert_id)
    .maybeSingle();

  if (alErr) {
    return jsonResponse(
      { error: "db_error", detail: alErr.message }, { status: 500 },
    );
  }
  if (!alert) {
    return jsonResponse({ error: "not_found" }, { status: 404 });
  }
  if (alert.device_id !== device.id || alert.organization_id !== device.organization_id) {
    return jsonResponse({ error: "forbidden" }, { status: 403 });
  }

  // 3. Compute the next status.
  const target = nextStatus(alert.status as AlertStatus, body.action as Action);
  if (!target) {
    return jsonResponse(
      {
        error: "invalid_transition",
        message: `cannot ${body.action} an alert that is ${alert.status}`,
        current_status: alert.status,
      },
      { status: 409 },
    );
  }

  // 4. Apply the transition.
  const now = new Date().toISOString();
  const patch: Record<string, unknown> = { status: target };

  if (target === "acknowledged") {
    patch.acknowledged_at = now;
    patch.acknowledged_by = body.actor ?? null;
  }
  if (target === "resolved") {
    patch.resolved_at = now;
    patch.resolved_by = body.actor ?? null;
  }
  if (target === "open") {
    // Reopen — clear the terminal timestamps.
    patch.acknowledged_at = null;
    patch.acknowledged_by = null;
    patch.resolved_at = null;
    patch.resolved_by = null;
  }

  const { data: updated, error: updErr } = await db
    .from("alerts")
    .update(patch)
    .eq("id", alert.id)
    .select("id, status, acknowledged_at, resolved_at")
    .single();

  if (updErr || !updated) {
    return jsonResponse(
      { error: "db_error", step: "update_alert", detail: updErr?.message ?? "no row returned" },
      { status: 500 },
    );
  }

  return jsonResponse({
    ok: true,
    alert_id: updated.id,
    status: updated.status,
    acknowledged_at: updated.acknowledged_at,
    resolved_at: updated.resolved_at,
  });
});
