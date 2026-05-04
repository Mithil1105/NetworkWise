// -----------------------------------------------------------------------------
// report-heartbeat  —  append a heartbeat row + bump devices.last_seen_at.
// -----------------------------------------------------------------------------
// POST /functions/v1/report-heartbeat
// Body:
//   {
//     "device_id":           "<uuid>",           // required
//     "registration_secret": "<opaque>",         // required
//     "cpu_usage_percent":   12.4,               // optional
//     "memory_used_gb":      5.8,                // optional
//     "memory_total_gb":     16.0,               // optional
//     "disk_used_gb":        180.3,              // optional
//     "disk_total_gb":       512.0,              // optional
//     "battery_percent":     78,                 // optional
//     "is_charging":         true,               // optional
//     "uptime_seconds":      345600              // optional
//   }
// -----------------------------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.5";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface HeartbeatPayload {
  device_id: string;
  registration_secret: string;
  cpu_usage_percent?: number;
  memory_used_gb?: number;
  memory_total_gb?: number;
  disk_used_gb?: number;
  disk_total_gb?: number;
  battery_percent?: number;
  is_charging?: boolean;
  uptime_seconds?: number;
  // Optional network / identity refresh fields — if present, patched
  // into the devices row in the same round-trip so the fleet list
  // stays in step with the endpoint's current LAN address, hostname,
  // and hardware inventory without a separate endpoint.
  ip_address?: string;
  mac_address?: string;
  hostname?: string;
  manufacturer?: string;
  model?: string;
  serial_number?: string;
  domain?: string;
  cpu_name?: string;
  cpu_cores?: number;
  architecture?: string;
  total_ram_gb?: number;
  // Active window (Phase 20) — what the user is currently working on,
  // captured by the endpoint probe via GetForegroundWindow + GetWindowText
  // and the owning process .exe.
  active_window_title?: string;
  active_process_name?: string;
  // Per-volume disk breakdown (Phase 21). Array of objects shaped like
  // { drive, total_gb, free_gb, label, file_system }. Stored verbatim
  // as JSONB on both heartbeat_logs (time series) and devices (latest).
  disks?: unknown;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, { status: 405 });
  }

  let body: Partial<HeartbeatPayload>;
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

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Authenticate — look up the device and verify the shared secret.
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

  // Insert heartbeat row. The active-window pair + disks JSONB make
  // every row a self-contained snapshot — Activity tab queries can run
  // off this single table without joining anywhere else.
  const stringIfNonEmpty = (v: unknown): string | null => {
    if (typeof v !== "string") return null;
    const t = v.trim();
    return t.length === 0 ? null : t;
  };
  const arrayIfPresent = (v: unknown): unknown =>
    Array.isArray(v) && v.length > 0 ? v : null;

  const { error: insErr } = await db.from("heartbeat_logs").insert({
    device_id: device.id,
    organization_id: device.organization_id,
    cpu_usage_percent: body.cpu_usage_percent ?? null,
    memory_used_gb: body.memory_used_gb ?? null,
    memory_total_gb: body.memory_total_gb ?? null,
    disk_used_gb: body.disk_used_gb ?? null,
    disk_total_gb: body.disk_total_gb ?? null,
    battery_percent: body.battery_percent ?? null,
    is_charging: body.is_charging ?? null,
    uptime_seconds: body.uptime_seconds ?? 0,
    active_window_title: stringIfNonEmpty(body.active_window_title)?.slice(0, 255) ?? null,
    active_process_name: stringIfNonEmpty(body.active_process_name)?.slice(0, 128) ?? null,
    disks: arrayIfPresent(body.disks),
    reported_at: now,
  });

  if (insErr) {
    return jsonResponse(
      { error: "db_error", step: "insert_heartbeat", detail: insErr.message },
      { status: 500 },
    );
  }

  // Stamp the device's last_seen_at so the Devices list "feels alive".
  // Also patch any network / identity fields the endpoint sent with
  // this heartbeat — IP and MAC in particular drift over time as the
  // user roams between networks, so the fleet list needs to see them
  // move without waiting for a full re-enrolment.
  const devicePatch: Record<string, unknown> = {
    last_seen_at: now,
    status: "online",
    uptime_seconds: body.uptime_seconds ?? 0,
  };
  const stringIfPresent = (v: unknown): string | undefined =>
    typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
  const numberIfPresent = (v: unknown): number | undefined =>
    typeof v === "number" && Number.isFinite(v) ? v : undefined;

  const ipAddress = stringIfPresent(body.ip_address);
  if (ipAddress) devicePatch.ip_address = ipAddress;
  const macAddress = stringIfPresent(body.mac_address);
  if (macAddress) devicePatch.mac_address = macAddress;
  const hostname = stringIfPresent(body.hostname);
  if (hostname) devicePatch.hostname = hostname;
  const manufacturer = stringIfPresent(body.manufacturer);
  if (manufacturer) devicePatch.manufacturer = manufacturer;
  const model = stringIfPresent(body.model);
  if (model) devicePatch.model = model;
  const serialNumber = stringIfPresent(body.serial_number);
  if (serialNumber) devicePatch.serial_number = serialNumber;
  const domain = stringIfPresent(body.domain);
  if (domain) devicePatch.domain = domain;
  const cpuName = stringIfPresent(body.cpu_name);
  if (cpuName) devicePatch.cpu_name = cpuName;
  const cpuCores = numberIfPresent(body.cpu_cores);
  if (cpuCores !== undefined) devicePatch.cpu_cores = cpuCores;
  const architecture = stringIfPresent(body.architecture);
  if (architecture) devicePatch.architecture = architecture;
  const totalRamGb = numberIfPresent(body.total_ram_gb);
  if (totalRamGb !== undefined) devicePatch.total_ram_gb = totalRamGb;

  // Active window — only stamp when the endpoint actually has a
  // foreground (locked desktops / session-0 services leave both fields
  // out so we don't blank the previous value during transient locks).
  // Truncate the title to 255 chars so a runaway browser tab can't
  // bloat the row.
  const activeWindowTitle = stringIfPresent(body.active_window_title);
  if (activeWindowTitle) {
    devicePatch.active_window_title = activeWindowTitle.slice(0, 255);
    devicePatch.active_window_seen_at = now;
  }
  const activeProcessName = stringIfPresent(body.active_process_name);
  if (activeProcessName) {
    devicePatch.active_process_name = activeProcessName.slice(0, 128);
  }
  // Per-volume disk breakdown (Phase 21) — stamp the latest array onto
  // the devices row so the Devices list / Device Detail screen can
  // render C: / D: / E: bars without re-deriving from heartbeat_logs.
  const latestDisks = arrayIfPresent(body.disks);
  if (latestDisks !== null) {
    devicePatch.disks = latestDisks;
  }

  const { error: updErr } = await db
    .from("devices")
    .update(devicePatch)
    .eq("id", device.id);

  if (updErr) {
    return jsonResponse(
      { error: "db_error", step: "touch_device", detail: updErr.message },
      { status: 500 },
    );
  }

  return jsonResponse({ ok: true, reported_at: now });
});
