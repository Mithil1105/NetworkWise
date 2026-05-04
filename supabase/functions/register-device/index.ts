// -----------------------------------------------------------------------------
// register-device  —  provisions a new endpoint.
// -----------------------------------------------------------------------------
// Called by the Flutter app exactly once per endpoint — on first run,
// right after the local DeviceIdentityService mints a v4 UUID.
//
// Contract
// ~~~~~~~~
// POST /functions/v1/register-device
// Body:
//   {
//     "device_uuid":      "<v4 uuid>",          // required
//     "enrollment_code":  "MSH-7F2K-91QR",      // preferred — looked up
//                                                //   in organizations.enrollment_code
//     "org_slug":         "mistry-and-shah",    // legacy fallback; one of
//                                                //   enrollment_code / org_slug MUST be set
//     "hostname":         "WIN-OFFICE-01",      // optional
//     "ip_address":  "192.168.1.24",       // optional
//     "mac_address": "A4:5E:60:1C:77:02",  // optional
//     "os":          "Windows 11 Pro",     // optional
//     "os_version":  "23H2",               // optional
//     "manufacturer":"Dell Inc.",          // optional
//     "model":       "OptiPlex 7090",      // optional
//     "assigned_user":"priya.mehta",       // optional
//     "location":    "Ahmedabad — HQ",     // optional
//     "serial_number":"MSH-001-...",       // optional
//     "domain":      "MISTRY-SHAH.LOCAL",  // optional
//     "environment": "production"          // optional; defaults to
//                                          // APP_ENV if present
//   }
// Response (200):
//   {
//     "device_id":           "<same uuid echoed back>",
//     "organization_id":     "<uuid>",
//     "registration_secret": "<opaque string>",
//     "enrolled_at":         "<iso8601>"
//   }
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ALLOWED_ORG_SLUGS = (Deno.env.get("ALLOWED_ORG_SLUGS") ?? "")
  .split(",")
  .map((s) => s.trim().toLowerCase())
  .filter(Boolean);

interface RegisterPayload {
  device_uuid: string;
  enrollment_code?: string;
  org_slug?: string;
  hostname?: string;
  ip_address?: string;
  mac_address?: string;
  os?: string;
  os_version?: string;
  manufacturer?: string;
  model?: string;
  assigned_user?: string;
  location?: string;
  serial_number?: string;
  domain?: string;
  cpu_name?: string;
  cpu_cores?: number;
  architecture?: string;
  total_ram_gb?: number;
  disk_total_gb?: number;
  environment?: "development" | "staging" | "production";
}

function isUuid(s: unknown): s is string {
  return typeof s === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      .test(s);
}

function validate(body: Partial<RegisterPayload>): string | null {
  if (!isUuid(body.device_uuid)) return "device_uuid must be a valid v4 UUID";

  const hasEnrollment =
    typeof body.enrollment_code === "string" && body.enrollment_code.length > 0;
  const hasSlug =
    typeof body.org_slug === "string" && body.org_slug.length > 0;

  if (!hasEnrollment && !hasSlug) {
    return "enrollment_code (preferred) or org_slug is required";
  }

  if (
    hasSlug &&
    ALLOWED_ORG_SLUGS.length > 0 &&
    !ALLOWED_ORG_SLUGS.includes((body.org_slug as string).toLowerCase())
  ) {
    return `org_slug '${body.org_slug}' is not allowed`;
  }
  if (
    body.environment !== undefined &&
    !["development", "staging", "production"].includes(body.environment)
  ) {
    return "environment must be one of development|staging|production";
  }
  return null;
}

function generateSecret(): string {
  // 32 bytes of entropy → 44-char base64url — short enough for headers,
  // long enough to be infeasible to guess.
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

// -----------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  let body: Partial<RegisterPayload>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, { status: 400 });
  }

  const validationError = validate(body);
  if (validationError) {
    return jsonResponse(
      { error: "validation_failed", message: validationError },
      { status: 400 },
    );
  }

  const payload = body as RegisterPayload;
  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Look up organisation — by enrollment_code first, then fall back to
  //    legacy org_slug for endpoints that still carry it in .env.
  let orgQuery = db.from("organizations").select("id, slug, enrollment_code");
  if (payload.enrollment_code && payload.enrollment_code.length > 0) {
    orgQuery = orgQuery.eq("enrollment_code", payload.enrollment_code.trim());
  } else {
    orgQuery = orgQuery.eq("slug", (payload.org_slug as string).trim());
  }

  const { data: org, error: orgErr } = await orgQuery.maybeSingle();

  if (orgErr) {
    return jsonResponse(
      { error: "db_error", step: "lookup_org", detail: orgErr.message },
      { status: 500 },
    );
  }
  if (!org) {
    return jsonResponse(
      {
        error: payload.enrollment_code ? "invalid_enrollment_code" : "unknown_org",
        message: payload.enrollment_code
          ? "No organisation matches that enrollment code. Ask your admin for the current code, or rotate it from the dashboard."
          : "No organisation exists for that slug. Seed one via 7-seed.sql.",
      },
      { status: 404 },
    );
  }

  // 2. Upsert the device — idempotent so re-registration after a
  //    network blip doesn't produce duplicates.
  const secret = generateSecret();
  const now = new Date().toISOString();

  const { data: upserted, error: upsertErr } = await db
    .from("devices")
    .upsert(
      {
        id: payload.device_uuid,
        organization_id: org.id,
        hostname: payload.hostname ?? null,
        ip_address: payload.ip_address ?? null,
        mac_address: payload.mac_address ?? null,
        os: payload.os ?? null,
        os_version: payload.os_version ?? null,
        manufacturer: payload.manufacturer ?? null,
        model: payload.model ?? null,
        assigned_user: payload.assigned_user ?? null,
        location: payload.location ?? null,
        serial_number: payload.serial_number ?? null,
        domain: payload.domain ?? null,
        cpu_name: payload.cpu_name ?? null,
        cpu_cores: payload.cpu_cores ?? null,
        architecture: payload.architecture ?? null,
        total_ram_gb: payload.total_ram_gb ?? null,
        disk_total_gb: payload.disk_total_gb ?? null,
        environment: payload.environment ?? "development",
        enrolled_at: now,
        last_seen_at: now,
        status: "online",
        health: "healthy",
        registration_secret: secret,
      },
      { onConflict: "id" },
    )
    .select("id, organization_id, enrolled_at")
    .single();

  if (upsertErr || !upserted) {
    return jsonResponse(
      {
        error: "db_error",
        step: "upsert_device",
        detail: upsertErr?.message ?? "no row returned",
      },
      { status: 500 },
    );
  }

  // 3. Return the provisioning receipt.
  return jsonResponse({
    device_id: upserted.id,
    organization_id: upserted.organization_id,
    registration_secret: secret,
    enrolled_at: upserted.enrolled_at,
  });
});
