-- =============================================================================
-- 3-indexes.sql
-- -----------------------------------------------------------------------------
-- Performance indexes on foreign-key columns, time-series reads, and
-- hot filter paths used by the Flutter app + the register-device /
-- report-snapshot Edge Functions. Safe to re-run.
-- =============================================================================

-- ---- devices -----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_devices_org
  ON public.devices (organization_id);

CREATE INDEX IF NOT EXISTS idx_devices_org_last_seen
  ON public.devices (organization_id, last_seen_at DESC);

CREATE INDEX IF NOT EXISTS idx_devices_org_status
  ON public.devices (organization_id, status);

-- ---- network_adapters --------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_adapters_device
  ON public.network_adapters (device_id, observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_adapters_org
  ON public.network_adapters (organization_id);

-- ---- security_status ---------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_security_device
  ON public.security_status (device_id, observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_security_org
  ON public.security_status (organization_id, observed_at DESC);

-- ---- alerts ------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_alerts_org_occurred
  ON public.alerts (organization_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_device_occurred
  ON public.alerts (device_id, occurred_at DESC);

-- Partial index — massively faster for the Alerts screen's "open only"
-- filter because open alerts are a small minority of all rows.
CREATE INDEX IF NOT EXISTS idx_alerts_open
  ON public.alerts (organization_id, occurred_at DESC)
  WHERE status = 'open';

-- ---- heartbeat_logs ----------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_heartbeat_device
  ON public.heartbeat_logs (device_id, reported_at DESC);

CREATE INDEX IF NOT EXISTS idx_heartbeat_org
  ON public.heartbeat_logs (organization_id, reported_at DESC);

-- ---- app_settings ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_app_settings_device
  ON public.app_settings (device_id);
