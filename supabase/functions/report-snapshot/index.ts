// -----------------------------------------------------------------------------
// report-snapshot  —  atomic snapshot of network_adapters + security_status.
// -----------------------------------------------------------------------------
// Body:
//   {
//     "device_id":           "<uuid>",
//     "registration_secret": "<opaque>",
//     "adapters": [
//       { "name":"Intel...", "type":"ethernet", "ip_address":"...", ... }
//     ],
//     "security": {
//       "antivirus_name":"Windows Defender",
//       "antivirus_enabled": true,
//       "antivirus_up_to_date": true,
//       "real_time_protection": true,
//       "last_scan_at": "2026-04-21T...",
//       "firewall_domain": "enabled",
//       "firewall_private": "enabled",
//       "firewall_public":  "enabled",
//       "windows_activated": true,
//       "bitlocker_enabled": true,
//       "last_update_check": "2026-04-20T..."
//     }
//   }
//
// Adapters are REPLACED (delete-all + insert) so the table always
// reflects the current physical state. security_status is APPENDED.
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface AdapterIn {
  name?: string;
  type?: "ethernet" | "wifi" | "virtual" | "cellular" | "unknown";
  mac_address?: string;
  ip_address?: string;
  subnet_mask?: string;
  gateway?: string;
  dns_servers?: string[];
  is_connected?: boolean;
  link_speed_mbps?: number;
  bytes_sent?: number;
  bytes_received?: number;
}

interface AntivirusProductIn {
  display_name?: string;
  product_id?: string;
  is_primary?: boolean;
  is_enabled?: boolean;
  is_up_to_date?: boolean;
  real_time_protection?: boolean;
  last_scan_at?: string;
  license_expires_at?: string;
  license_source?: "wsc" | "registry" | "manual" | "unknown";
}

interface SecurityIn {
  antivirus_name?: string;
  antivirus_enabled?: boolean;
  antivirus_up_to_date?: boolean;
  real_time_protection?: boolean;
  last_scan_at?: string;
  firewall_domain?: "enabled" | "disabled" | "unknown";
  firewall_private?: "enabled" | "disabled" | "unknown";
  firewall_public?: "enabled" | "disabled" | "unknown";
  windows_activated?: boolean;
  bitlocker_enabled?: boolean;
  last_update_check?: string;
  // Full inventory discovered by the WSC probe — Defender plus any
  // third-party AV registered with Windows Security Center. If
  // present the Edge Function mirrors the list into
  // `security_antivirus_products` so the admin can see every engine
  // side-by-side.
  antivirus_products?: AntivirusProductIn[];
}

interface SnapshotPayload {
  device_id: string;
  registration_secret: string;
  adapters: AdapterIn[];
  security: SecurityIn;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  let body: Partial<SnapshotPayload>;
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
  const adapters = Array.isArray(body.adapters) ? body.adapters : [];
  const security = body.security ?? {};

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

  const now = new Date().toISOString();

  // ---- adapters: delete-all then insert ----
  const { error: delErr } = await db
    .from("network_adapters")
    .delete()
    .eq("device_id", device.id);
  if (delErr) {
    return jsonResponse(
      { error: "db_error", step: "clear_adapters", detail: delErr.message },
      { status: 500 },
    );
  }

  if (adapters.length > 0) {
    const adapterRows = adapters.map((a) => ({
      device_id: device.id,
      organization_id: device.organization_id,
      name: a.name ?? null,
      type: a.type ?? "unknown",
      mac_address: a.mac_address ?? null,
      ip_address: a.ip_address ?? null,
      subnet_mask: a.subnet_mask ?? null,
      gateway: a.gateway ?? null,
      dns_servers: a.dns_servers ?? [],
      is_connected: a.is_connected ?? false,
      link_speed_mbps: a.link_speed_mbps ?? null,
      bytes_sent: a.bytes_sent ?? 0,
      bytes_received: a.bytes_received ?? 0,
      observed_at: now,
    }));
    const { error: insAdErr } = await db
      .from("network_adapters")
      .insert(adapterRows);
    if (insAdErr) {
      return jsonResponse(
        { error: "db_error", step: "insert_adapters", detail: insAdErr.message },
        { status: 500 },
      );
    }
  }

  // ---- security_status: append new row ----
  const { error: insSecErr } = await db.from("security_status").insert({
    device_id: device.id,
    organization_id: device.organization_id,
    antivirus_name: security.antivirus_name ?? null,
    antivirus_enabled: security.antivirus_enabled ?? false,
    antivirus_up_to_date: security.antivirus_up_to_date ?? false,
    real_time_protection: security.real_time_protection ?? false,
    last_scan_at: security.last_scan_at ?? null,
    firewall_domain: security.firewall_domain ?? "unknown",
    firewall_private: security.firewall_private ?? "unknown",
    firewall_public: security.firewall_public ?? "unknown",
    windows_activated: security.windows_activated ?? false,
    bitlocker_enabled: security.bitlocker_enabled ?? false,
    last_update_check: security.last_update_check ?? null,
    observed_at: now,
  });
  if (insSecErr) {
    return jsonResponse(
      { error: "db_error", step: "insert_security", detail: insSecErr.message },
      { status: 500 },
    );
  }

  // ---- security_antivirus_products: REPLACE the full AV inventory ----
  // Delete-then-upsert keeps the table in lockstep with the endpoint's
  // current set of engines — uninstalling an AV locally removes it
  // from the dashboard on the next snapshot.
  const avProducts = Array.isArray(security.antivirus_products)
    ? security.antivirus_products
    : [];
  const { error: delAvErr } = await db
    .from("security_antivirus_products")
    .delete()
    .eq("device_id", device.id);
  if (delAvErr) {
    return jsonResponse(
      { error: "db_error", step: "clear_av_products", detail: delAvErr.message },
      { status: 500 },
    );
  }

  if (avProducts.length > 0) {
    const avRows = avProducts.map((p) => ({
      device_id: device.id,
      organization_id: device.organization_id,
      display_name: p.display_name ?? "Unknown",
      product_id: p.product_id ?? null,
      is_primary: p.is_primary ?? false,
      is_enabled: p.is_enabled ?? false,
      is_up_to_date: p.is_up_to_date ?? false,
      real_time_protection: p.real_time_protection ?? false,
      last_scan_at: p.last_scan_at ?? null,
      license_expires_at: p.license_expires_at ?? null,
      license_source: p.license_source ?? "unknown",
      observed_at: now,
    }));
    const { error: insAvErr } = await db
      .from("security_antivirus_products")
      .insert(avRows);
    if (insAvErr) {
      return jsonResponse(
        { error: "db_error", step: "insert_av_products", detail: insAvErr.message },
        { status: 500 },
      );
    }
  }

  return jsonResponse({
    ok: true,
    adapters: adapters.length,
    antivirus_products: avProducts.length,
    observed_at: now,
  });
});
