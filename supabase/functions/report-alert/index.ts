// -----------------------------------------------------------------------------
// report-alert  —  insert a new row into `alerts`.
// -----------------------------------------------------------------------------
// Body:
//   {
//     "device_id":           "<uuid>",
//     "registration_secret": "<opaque>",
//     "title":               "Disk almost full",
//     "message":             "...",
//     "severity":            "high",                // info|low|medium|high|critical
//     "category":            "system",              // system|network|security|performance|other
//     "source":              "WMI",                 // optional
//     "occurred_at":         "2026-04-21T..."       // optional; server now() if absent
//   }
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const SEVERITIES = ["info", "low", "medium", "high", "critical"] as const;
const CATEGORIES = ["system", "network", "security", "performance", "other"] as const;

type Severity = typeof SEVERITIES[number];
type Category = typeof CATEGORIES[number];

interface AlertPayload {
  device_id: string;
  registration_secret: string;
  title: string;
  message?: string;
  severity: Severity;
  category: Category;
  source?: string;
  occurred_at?: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  let body: Partial<AlertPayload>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, { status: 400 });
  }

  if (!body.device_id || !body.registration_secret) {
    return jsonResponse(
      { error: "validation_failed", message: "device_id and registration_secret are required" },
      { status: 400 },
    );
  }
  if (!body.title || typeof body.title !== "string") {
    return jsonResponse(
      { error: "validation_failed", message: "title is required" },
      { status: 400 },
    );
  }
  if (!SEVERITIES.includes(body.severity as Severity)) {
    return jsonResponse(
      { error: "validation_failed", message: "severity out of range" },
      { status: 400 },
    );
  }
  if (!CATEGORIES.includes(body.category as Category)) {
    return jsonResponse(
      { error: "validation_failed", message: "category out of range" },
      { status: 400 },
    );
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

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

  const occurredAt = body.occurred_at ?? new Date().toISOString();

  const { data: inserted, error: insErr } = await db
    .from("alerts")
    .insert({
      organization_id: device.organization_id,
      device_id: device.id,
      title: body.title,
      message: body.message ?? null,
      severity: body.severity,
      category: body.category,
      source: body.source ?? null,
      occurred_at: occurredAt,
    })
    .select("id, occurred_at")
    .single();

  if (insErr || !inserted) {
    return jsonResponse(
      { error: "db_error", step: "insert_alert", detail: insErr?.message ?? "no row returned" },
      { status: 500 },
    );
  }

  return jsonResponse({ ok: true, alert_id: inserted.id, occurred_at: inserted.occurred_at });
});
