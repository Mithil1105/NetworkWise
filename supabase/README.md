# NetworkWise — Supabase Backend

This folder contains everything the Supabase project needs:

- Numbered SQL files (`1-*.sql` … `11-*.sql`) — run in order via the SQL Editor.
- `functions/` — Edge Functions deployed via the Supabase CLI.
- This README — deployment steps + integration testing checklist.

---

## 1. Supabase Project Setup — Step-by-Step

| # | Step | Location | Notes |
| - | ---- | -------- | ----- |
| 1 | Create a new Supabase project | app.supabase.com — New Project | Use the region closest to Ahmedabad (ap-south-1). |
| 2 | Note the Project URL + anon key | Project Settings — API | These go into the Flutter app's `.env`. |
| 3 | Note the `service_role` key | Project Settings — API | **Server-only.** Used by Edge Function secrets — never paste into the client. |
| 4 | Run SQL files in order | SQL Editor → "New query" | See table below. |
| 5 | Enable Realtime on `devices`, `alerts`, `app_settings`, `organizations` | Database — Replication | Toggle each table's "Source" switch. `organizations` is required so the dashboard picks up enrollment-code rotations in real time. |
| 6 | Deploy Edge Functions | Supabase CLI | See "Edge Function deployment" below. |
| 7 | Set Edge Function secrets | CLI or Dashboard | `ALLOWED_ORG_SLUGS=mistry-and-shah`. |
| 8 | Seed the first Owner admin | SQL Editor | Edit `10-seed-admin.sql` — replace `OWNER_EMAIL_PLACEHOLDER` with the first admin's email after creating the auth user in Dashboard → Authentication → Users. |
| 9 | Configure the Flutter app's `.env` | `network_wise/.env` | Copy from `.env.example`. |
| 10 | Run the Flutter app once | `flutter run -d windows` | First run registers the endpoint — watch the Logs panel in Supabase Dashboard. |

### 1a. SQL execution order (hard requirement)

| # | File | Purpose | Re-runnable? |
| - | ---- | ------- | ------------ |
| 1 | `1-extensions.sql` | `pgcrypto`, `citext`, `touch_updated_at()` | Yes — idempotent. |
| 2 | `2-tables.sql` | 7 tables (organizations, devices, network_adapters, security_status, alerts, heartbeat_logs, app_settings) | Yes — uses `CREATE TABLE IF NOT EXISTS`. |
| 3 | `3-indexes.sql` | Performance indexes incl. partial index on open alerts | Yes. |
| 4 | `4-triggers.sql` | `updated_at` touch triggers on mutable tables | Yes. |
| 5 | `5-rls-enable.sql` | `ALTER TABLE … ENABLE ROW LEVEL SECURITY` on every table | Yes. |
| 6 | `6-rls-policies.sql` | `request_header()` helper + anon SELECT scoped by `x-org-id` header | Yes — uses `CREATE OR REPLACE` / `DROP POLICY IF EXISTS`. |
| 7 | `7-seed.sql` | Inserts the `mistry-and-shah` organisation + org-default `app_settings` row | Yes — uses `ON CONFLICT DO NOTHING`. |
| 8 | `8-enrollment-code.sql` | Adds `enrollment_code` + `enrollment_code_rotated_at` columns to `organizations`, plus the `enrollment_code_lookups` audit table. Policies let endpoints resolve the current code on first-run bootstrap. | Yes — idempotent. |
| 9 | `9-admin-members.sql` | Creates `admin_members` (dashboard sign-in accounts), the `current_admin_org_id()` helper, and the `devices_admin_update`/`orgs_admin_*` policies that gate admin writes. | Yes. |
| 10 | `10-seed-admin.sql` | **Template** — links the first admin `auth.users` record to the `mistry-and-shah` organisation as an Owner. Edit the `OWNER_EMAIL_PLACEHOLDER` before running. | Re-runnable once edited — uses `ON CONFLICT DO NOTHING`. |
| 11 | `11-device-admin.sql` | Adds `hostname_label` + `archived_at` columns on `devices` plus an index on `archived_at`. Enables rename + soft-delete from the dashboard. | Yes — idempotent. |

---

## 2. Edge Function deployment

Install the CLI if you have not already: `npm i -g supabase`.

```powershell
# Link this folder to your Supabase project (one-time):
supabase link --project-ref <your-project-ref>

# Set the secret that register-device uses to guard tenant attachment:
supabase secrets set ALLOWED_ORG_SLUGS=mistry-and-shah

# Deploy the seven functions:
supabase functions deploy register-device
supabase functions deploy report-heartbeat
supabase functions deploy report-snapshot
supabase functions deploy report-alert
supabase functions deploy update-alert-status
supabase functions deploy rotate-enrollment-code
supabase functions deploy invite-admin
```

The `_shared/cors.ts` helper is bundled automatically by the deploy step — no separate command is needed.

### 2a. What each function does

| Function | Caller | Purpose | Writes |
| -------- | ------ | ------- | ------ |
| `register-device` | Flutter bootstrap (first run) | Resolves the enrollment code → tenant, upserts the `devices` row, mints a `registration_secret`, returns it to the client. | `devices`, `enrollment_code_lookups` |
| `report-heartbeat` | HeartbeatLoop (every `heartbeat_seconds`) | Append a telemetry row and bump `devices.last_seen_at`. | `heartbeat_logs`, `devices` |
| `report-snapshot` | HeartbeatLoop (same cadence or longer) | Replace network adapters atomically; append a security snapshot. | `network_adapters`, `security_status` |
| `report-alert` | Any local monitor | Create a new alert for this device. | `alerts` |
| `update-alert-status` | Dashboard (operator) | Acknowledge / resolve / reopen an alert with legal transitions only. | `alerts` |
| `rotate-enrollment-code` | Dashboard Settings → Enrollment panel | Admin-only. Generates a fresh `MSH-XXXX-YYYY` code, stamps `enrollment_code_rotated_at`, returns the new code. Previous code is invalidated immediately. | `organizations` |
| `invite-admin` | Dashboard Settings → Admins panel | Admin-only. Creates an `auth.users` row (email + initial password, email confirmed) and links it to the same organisation as the caller. Only owners can mint owners. | `auth.users`, `admin_members` |

---

## 3. Flutter `.env` reference

The values below must be present in `network_wise/.env` before `flutter run`:

| Key | Example | Required | Notes |
| --- | ------- | -------- | ----- |
| `SUPABASE_URL` | `https://abcdxyz.supabase.co` | Yes | Project URL from Dashboard. |
| `SUPABASE_ANON_KEY` | `eyJhbGciOi…` | Yes | Public anon key — RLS guards it. |
| `APP_ROLE` | `admin` | Yes | `endpoint` for monitored Windows boxes (default); `admin` for the dashboard build. Drives first-run flow + Settings panel visibility. |
| `APP_ORG_SLUG` | `mistry-and-shah` | No* | Only needed for the admin build as a bootstrap fallback. Endpoint builds resolve the org via the enrollment code instead. |
| `APP_ENV` | `production` | No | One of `development` / `staging` / `production`. Defaults to `development`. |
| `APP_DATA_SOURCE` | `supabase` | No | `mock` to force the in-memory service; `supabase` to force the cloud service. Defaults to auto-detect based on `SUPABASE_URL` presence. |
| `APP_HEARTBEAT_SECONDS` | `60` | No | Boot override for heartbeat cadence. Clamped to 10 – 600 on the server. |

---

## 4. Integration testing checklist

Run end-to-end after deploying the SQL + Edge Functions. Tick each row.

### 4a. Bootstrap + registration

| # | Test | Expected | Where to verify |
| - | ---- | -------- | --------------- |
| 1 | Fresh install — first `flutter run` | `bootstrapProvider` goes `idle → resolvingIdentity → registering → ready` | Flutter debug console + `devices` table in Supabase. |
| 2 | `devices` row exists with the client-minted UUID | `status='online'`, `health='healthy'`, `registration_secret` populated | SQL Editor — `SELECT id, hostname, status FROM devices;` |
| 3 | Second cold start | No new row, `bootstrapProvider` resolves to `ready` instantly | Row count unchanged. |
| 4 | `APP_ORG_SLUG` typo | Bootstrap emits `failed` with `unknown_org` | Splash screen error banner. |
| 5 | `.env` missing `SUPABASE_URL` | `Env.load()` throws with a clear key name | Stack trace in console. |

### 4b. Reads (PostgREST + RLS)

| # | Test | Expected | Where to verify |
| - | ---- | -------- | --------------- |
| 6 | Dashboard renders the real fleet | Devices table populated; last_seen_at within 2 min | Devices screen. |
| 7 | Strip the `x-org-id` header (temp hack) | Zero rows | curl against `/rest/v1/devices`. |
| 8 | Two orgs seeded side-by-side | Each only sees its own devices | Dashboard pointed at org A vs org B. |

### 4c. Writes via Edge Functions

| # | Test | Expected | Where to verify |
| - | ---- | -------- | --------------- |
|  9 | `report-heartbeat` cadence | `heartbeat_logs` rows arrive every N seconds | `SELECT reported_at FROM heartbeat_logs ORDER BY reported_at DESC LIMIT 10;` |
| 10 | `report-snapshot` replaces adapters | Old adapter rows gone, new set present | `SELECT name FROM network_adapters WHERE device_id = :uuid;` |
| 11 | `report-snapshot` appends security | New `security_status` row each call | Row count grows on every tick. |
| 12 | `report-alert` with invalid severity | 400 `validation_failed` | Function Logs. |
| 13 | `update-alert-status` illegal transition (resolve → acknowledge) | 409 `invalid_transition` | Function Logs. |
| 14 | Ack / resolve round-trip | `alerts.status`, `acknowledged_at`, `resolved_at` set correctly | Alerts table + Alerts screen. |

### 4d. Admin sign-in + enrollment (Phase 14/15/16)

| # | Test | Expected | Where to verify |
| - | ---- | -------- | --------------- |
| 19 | First boot of an endpoint build with a fresh org | Enrollment screen blocks bootstrap until the correct `MSH-XXXX-YYYY` code is entered | Splash + `devices` row appears after success. |
| 20 | Enter a wrong code | Error banner `invalid_code`; no row created | `register-device` function logs. |
| 21 | Admin signs in on the dashboard build | Auth session persists across restart; Settings tab surfaces Enrollment + Admins panels | Dashboard top-right identity chip. |
| 22 | Admin rotates the enrollment code | New code returned, masked by default with reveal + copy | `organizations.enrollment_code_rotated_at` bumped. |
| 23 | Previously used code is presented on a new endpoint | Bootstrap fails with `invalid_code` | `enrollment_code_lookups` row records the miss. |
| 24 | Owner invites a new admin with role=admin | Banner: "user invited as ADMIN"; new row in `admin_members`; the new admin can sign in | Dashboard → Admins panel. |
| 25 | Non-owner tries to invite role=owner | Edge Function returns `forbidden`; UI shows the mapped friendly error | `invite-admin` logs. |
| 26 | Admin renames a device via Edit dialog | `devices.hostname_label` updated; device list + detail header use the new label, raw `hostname` unchanged | `SELECT hostname, hostname_label FROM devices WHERE id = :uuid;` |
| 27 | Admin archives a device | `archived_at` stamped, device hidden from the default list, appears under "Including archived" toggle with a badge | Devices list + `SELECT archived_at FROM devices WHERE id = :uuid;` |
| 28 | Admin restores an archived device | `archived_at` cleared; device back in the default view | Same query returns NULL. |

### 4e. Resilience

| # | Test | Expected | Where to verify |
| - | ---- | -------- | --------------- |
| 15 | Kill network mid-heartbeat | Op queued in `shared_preferences` `sync.queue.v1` | Prefs file. |
| 16 | Restore network | Queue drains in FIFO order within one tick (default 30 s) | `heartbeat_logs` rows resume. |
| 17 | Uninstall + reinstall | Endpoint re-registers under the same UUID (DPAPI persists) | Same `devices.id` on Supabase. |
| 18 | Manual `DeviceIdentityService.clear()` | Next boot mints a new UUID; old row remains for audit | Two rows in `devices`, the newer one active. |

---

## 5. Folder map — what lives where in the Flutter app

| Layer | Path | Role |
| ----- | ---- | ---- |
| Config | `lib/core/config/env.dart` | Typed `.env` accessor. |
| Identity | `lib/core/services/device_identity_service.dart` | UUID + registration-secret vault (DPAPI + prefs). |
| SDK | `lib/core/services/supabase_service.dart` | `Supabase.initialize()` wrapper + service provider. |
| Contracts | `lib/core/repositories/i_*.dart` | Pure interfaces for Devices, Alerts, Security, Adapters, Heartbeat, AppSettings. |
| Supabase impls | `lib/core/repositories/supabase/*.dart` | PostgREST reads + Edge Function writes. |
| RLS binder | `lib/core/repositories/supabase/supabase_headers.dart` | Stamps `x-org-id` on every PostgREST call. |
| Data service | `lib/core/services/supabase_data_service.dart` | Cache-in-front-of-repositories `IDataService` used by providers. |
| Mode switch | `lib/core/services/data_service_provider.dart` | Picks mock vs Supabase from `APP_DATA_SOURCE`. |
| Bootstrap | `lib/core/bootstrap/device_bootstrap.dart` + `bootstrap_provider.dart` | First-run orchestration. |
| Sync queue | `lib/core/sync/sync_queue.dart` + `sync_queue_provider.dart` | Offline write buffer (prefs-persisted). |

---

## 6. Manual dashboard steps that cannot be automated

These are the one-time clicks you must perform in the Supabase Dashboard.

| # | Action | Location | Why it is manual |
| - | ------ | -------- | ---------------- |
| 1 | Enable "Realtime" on the three tables | Database — Replication | Flipping the toggles requires Owner permissions. |
| 2 | Paste the `service_role` key into function secrets | Edge Functions — Secrets | Secrets are write-only — they cannot be seeded from SQL. |
| 3 | Optional — lock origin allow-list | Project Settings — API | Restrict to your dashboard URL once the app is in production. |
| 4 | Optional — enable Point-in-time recovery | Database — Backups | Needed if the CA firm's retention policy requires it. |

---

## 7. Roll-back

If something goes wrong during an upgrade:

```sql
-- Disable RLS temporarily (never in production):
alter table public.devices disable row level security;

-- Re-run any SQL file idempotently:
\i 6-rls-policies.sql
```

Edge Functions can be rolled back with `supabase functions delete <name>` followed by a deploy of the prior revision — keep the previous `index.ts` in git before cutting a release.
