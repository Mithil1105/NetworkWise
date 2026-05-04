-- =============================================================================
-- 2-tables.sql
-- -----------------------------------------------------------------------------
-- Creates all 7 tables. Must run AFTER 1-extensions.sql because several
-- columns default to gen_random_uuid(). The order below respects
-- foreign-key dependencies — do not re-order.
--
-- Convention:
--   * every mutable table has created_at + updated_at timestamptz
--   * append-only tables (security_status, heartbeat_logs) have
--     created_at only (their update semantics is "insert a new row")
--   * `organization_id` is denormalised onto every child table so RLS
--     policies can check it without a JOIN
-- =============================================================================

-- -----------------------------------------------------------------------------
-- organizations
-- -----------------------------------------------------------------------------
-- One tenant per CA firm / client estate. `slug` is what the Flutter
-- app passes in `.env APP_ORG_SLUG` when the endpoint registers.
CREATE TABLE IF NOT EXISTS public.organizations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        citext UNIQUE NOT NULL,
  name        text   NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.organizations IS 'Tenant / CA firm that owns a fleet of endpoints.';
COMMENT ON COLUMN public.organizations.slug IS 'Short URL-safe identifier — matches APP_ORG_SLUG in the Flutter .env.';

-- -----------------------------------------------------------------------------
-- devices
-- -----------------------------------------------------------------------------
-- Canonical record of each endpoint. `id` is a client-minted v4 UUID
-- (see lib/core/services/device_identity_service.dart) so first-run
-- registration is idempotent even if the network drops mid-request.
CREATE TABLE IF NOT EXISTS public.devices (
  id                  uuid PRIMARY KEY,
  organization_id     uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  -- Identity
  hostname            text,
  ip_address          text,
  mac_address         text,
  os                  text,
  os_version          text,
  manufacturer        text,
  model               text,
  assigned_user       text,
  location            text,
  serial_number       text,
  domain              text,
  tags                text[] NOT NULL DEFAULT ARRAY[]::text[],

  -- State
  status              text NOT NULL DEFAULT 'unknown'
                      CHECK (status IN ('online','offline','warning','unknown')),
  health              text NOT NULL DEFAULT 'unknown'
                      CHECK (health IN ('healthy','warning','critical','unknown')),
  last_seen_at        timestamptz,
  uptime_seconds      bigint NOT NULL DEFAULT 0,
  environment         text NOT NULL DEFAULT 'development'
                      CHECK (environment IN ('development','staging','production')),

  -- Provisioning
  enrolled_at         timestamptz,
  registration_secret text,   -- shared secret issued by register-device Edge Fn

  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  UNIQUE (organization_id, hostname)
);

COMMENT ON COLUMN public.devices.id IS 'v4 UUID minted client-side and persisted to DPAPI/SharedPreferences.';
COMMENT ON COLUMN public.devices.registration_secret IS 'Bcrypt-hashed secret returned by register-device; matched on every write.';

-- -----------------------------------------------------------------------------
-- network_adapters
-- -----------------------------------------------------------------------------
-- One row per adapter observed at the latest snapshot. The repository
-- layer REPLACES all rows for a device on each snapshot push, so this
-- is effectively a denormalised current-state table.
CREATE TABLE IF NOT EXISTS public.network_adapters (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id        uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  organization_id  uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  name             text,
  type             text NOT NULL DEFAULT 'unknown'
                   CHECK (type IN ('ethernet','wifi','virtual','cellular','unknown')),
  mac_address      text,
  ip_address       text,
  subnet_mask      text,
  gateway          text,
  dns_servers      text[] NOT NULL DEFAULT ARRAY[]::text[],
  is_connected     boolean NOT NULL DEFAULT false,
  link_speed_mbps  numeric(10,2),
  bytes_sent       bigint NOT NULL DEFAULT 0,
  bytes_received   bigint NOT NULL DEFAULT 0,
  observed_at      timestamptz NOT NULL DEFAULT now(),

  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- security_status  (append-only time-series)
-- -----------------------------------------------------------------------------
-- Inserted on each snapshot push. Latest row per device is used by the
-- Security screen; older rows support trend analysis.
CREATE TABLE IF NOT EXISTS public.security_status (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id              uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  organization_id        uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  antivirus_name         text,
  antivirus_enabled      boolean NOT NULL DEFAULT false,
  antivirus_up_to_date   boolean NOT NULL DEFAULT false,
  real_time_protection   boolean NOT NULL DEFAULT false,
  last_scan_at           timestamptz,

  firewall_domain        text NOT NULL DEFAULT 'unknown'
                         CHECK (firewall_domain IN ('enabled','disabled','unknown')),
  firewall_private       text NOT NULL DEFAULT 'unknown'
                         CHECK (firewall_private IN ('enabled','disabled','unknown')),
  firewall_public        text NOT NULL DEFAULT 'unknown'
                         CHECK (firewall_public IN ('enabled','disabled','unknown')),

  windows_activated      boolean NOT NULL DEFAULT false,
  bitlocker_enabled      boolean NOT NULL DEFAULT false,
  last_update_check      timestamptz,
  observed_at            timestamptz NOT NULL DEFAULT now(),

  created_at             timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- alerts
-- -----------------------------------------------------------------------------
-- Fleet-wide incident feed. device_id is nullable so org-level alerts
-- (e.g. "license server unreachable") can be recorded.
CREATE TABLE IF NOT EXISTS public.alerts (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id        uuid REFERENCES public.devices(id) ON DELETE CASCADE,

  title            text NOT NULL,
  message          text,
  severity         text NOT NULL DEFAULT 'info'
                   CHECK (severity IN ('info','low','medium','high','critical')),
  status           text NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open','acknowledged','resolved')),
  category         text NOT NULL DEFAULT 'other'
                   CHECK (category IN ('system','network','security','performance','other')),
  source           text,

  occurred_at      timestamptz NOT NULL DEFAULT now(),
  acknowledged_at  timestamptz,
  resolved_at      timestamptz,

  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- heartbeat_logs  (append-only time-series)
-- -----------------------------------------------------------------------------
-- Inserted every heartbeat_seconds. Carries a minimal system snapshot
-- so the Dashboard KPIs can compute online/offline + resource usage
-- without firing snapshot queries against every device.
CREATE TABLE IF NOT EXISTS public.heartbeat_logs (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id             uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  organization_id       uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  cpu_usage_percent     numeric(5,2),
  memory_used_gb        numeric(7,2),
  memory_total_gb       numeric(7,2),
  disk_used_gb          numeric(10,2),
  disk_total_gb         numeric(10,2),
  battery_percent       int,
  is_charging           boolean,
  uptime_seconds        bigint NOT NULL DEFAULT 0,

  reported_at           timestamptz NOT NULL DEFAULT now(),
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- app_settings
-- -----------------------------------------------------------------------------
-- Per-device user preferences (heartbeat cadence, thresholds, theme).
-- A device_id of NULL represents the org-wide default — last-write-wins
-- semantics apply. UNIQUE constraint lets the repository upsert cleanly.
CREATE TABLE IF NOT EXISTS public.app_settings (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id            uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  device_id                  uuid REFERENCES public.devices(id) ON DELETE CASCADE,

  theme_mode                 text NOT NULL DEFAULT 'light'
                             CHECK (theme_mode IN ('light','dark','system')),
  heartbeat_seconds          int  NOT NULL DEFAULT 30
                             CHECK (heartbeat_seconds BETWEEN 10 AND 600),
  storage_threshold_percent  numeric(5,2) NOT NULL DEFAULT 85.00
                             CHECK (storage_threshold_percent BETWEEN 50 AND 99),
  cpu_warning_percent        numeric(5,2) NOT NULL DEFAULT 80.00
                             CHECK (cpu_warning_percent BETWEEN 50 AND 99),
  memory_warning_percent     numeric(5,2) NOT NULL DEFAULT 85.00
                             CHECK (memory_warning_percent BETWEEN 50 AND 99),

  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),

  UNIQUE (organization_id, device_id)
);
