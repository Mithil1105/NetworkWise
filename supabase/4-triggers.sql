-- =============================================================================
-- 4-triggers.sql
-- -----------------------------------------------------------------------------
-- Attaches the shared touch_updated_at() trigger to every mutable
-- table so UPDATE statements automatically bump updated_at. Append-only
-- tables (security_status, heartbeat_logs) are skipped — they only ever
-- INSERT and their created_at already captures the write time.
-- =============================================================================

-- Helper: drop then recreate so this file is re-runnable without
-- "trigger already exists" errors.
DROP TRIGGER IF EXISTS trg_organizations_touch     ON public.organizations;
DROP TRIGGER IF EXISTS trg_devices_touch           ON public.devices;
DROP TRIGGER IF EXISTS trg_network_adapters_touch  ON public.network_adapters;
DROP TRIGGER IF EXISTS trg_alerts_touch            ON public.alerts;
DROP TRIGGER IF EXISTS trg_app_settings_touch      ON public.app_settings;

CREATE TRIGGER trg_organizations_touch
BEFORE UPDATE ON public.organizations
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_devices_touch
BEFORE UPDATE ON public.devices
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_network_adapters_touch
BEFORE UPDATE ON public.network_adapters
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_alerts_touch
BEFORE UPDATE ON public.alerts
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_app_settings_touch
BEFORE UPDATE ON public.app_settings
FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
