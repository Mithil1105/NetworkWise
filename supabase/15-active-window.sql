-- =============================================================================
-- 15-active-window.sql
-- -----------------------------------------------------------------------------
-- Adds "active window" columns to `devices` so the dashboard can show, at a
-- glance, what each endpoint is currently working on. The endpoint probe
-- captures `GetForegroundWindow()` + `GetWindowText()` + the owning process
-- name on every heartbeat tick; the report-heartbeat Edge Function patches
-- the columns below in the same round-trip.
--
-- The column lives on `devices` (not `heartbeat_logs`) because the dashboard
-- only ever cares about the *latest* window. Historical activity tracking
-- is intentionally out of scope — the heartbeat cadence (60s by default)
-- is too coarse for proper time-tracking and the UX should not pretend
-- otherwise.
--
-- Privacy note for operators (not enforced here, just documented):
--   * The captured value is the visible WINDOW TITLE, which can include
--     document names, browser tabs, email subjects, etc.
--   * Use a workplace-monitoring policy / employee acknowledgement before
--     enabling the endpoint build on staff machines. Local labour law in
--     India (Information Technology Act + recently issued DPDP Act 2023)
--     allows employer monitoring on company-owned devices but consent +
--     written notice is best practice.
--
-- Re-runnable. Every ALTER is guarded with IF NOT EXISTS.
-- =============================================================================

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS active_window_title    text,
  ADD COLUMN IF NOT EXISTS active_process_name    text,
  ADD COLUMN IF NOT EXISTS active_window_seen_at  timestamptz;

COMMENT ON COLUMN public.devices.active_window_title   IS 'Title of the foreground window at the latest heartbeat — empty when locked.';
COMMENT ON COLUMN public.devices.active_process_name   IS 'Owning process .exe (no path) — e.g. "EXCEL.EXE", "chrome.exe".';
COMMENT ON COLUMN public.devices.active_window_seen_at IS 'Server-stamped wallclock when the active window was last refreshed.';
