-- =============================================================================
-- 16-activity-history.sql
-- -----------------------------------------------------------------------------
-- Phase 22 — adds the two active-window columns to `heartbeat_logs` so every
-- 60-second tick becomes a sample of "what was the user working on at that
-- moment". Aggregating the rows by process_name × date gives us app-usage
-- minutes and total active screen time per device per day, with no extra
-- agent-side instrumentation.
--
-- We also tack on the per-disk JSON blob the probe now emits — same row,
-- one round-trip, so the remote Device Detail screen can show C:/D:/E:
-- breakdown for any endpoint, not only the locally-running PC.
--
-- Re-runnable. Every ALTER is guarded with IF NOT EXISTS.
-- =============================================================================

ALTER TABLE public.heartbeat_logs
  ADD COLUMN IF NOT EXISTS active_window_title text,
  ADD COLUMN IF NOT EXISTS active_process_name text,
  ADD COLUMN IF NOT EXISTS disks               jsonb;

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS disks               jsonb;

COMMENT ON COLUMN public.heartbeat_logs.active_window_title IS 'Foreground window title at this tick. Used to derive screen-time history.';
COMMENT ON COLUMN public.heartbeat_logs.active_process_name IS 'Foreground process .exe at this tick. GROUP BY this for app-minutes.';
COMMENT ON COLUMN public.heartbeat_logs.disks               IS 'Per-volume snapshot at this tick. Array of {drive,total_gb,free_gb,label,file_system}.';
COMMENT ON COLUMN public.devices.disks                       IS 'Latest per-volume snapshot — refreshed on every heartbeat.';

-- Index that keeps "minutes per app today" snappy. Without it the
-- Activity tab does a full per-device scan, which is fine on day one
-- but degrades fast once heartbeat_logs has a million rows.
CREATE INDEX IF NOT EXISTS heartbeat_logs_device_app_idx
  ON public.heartbeat_logs (device_id, active_process_name, reported_at DESC)
  WHERE active_process_name IS NOT NULL;
