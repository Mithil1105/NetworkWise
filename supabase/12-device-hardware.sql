-- =============================================================================
-- 12-device-hardware.sql
-- -----------------------------------------------------------------------------
-- Adds static hardware-inventory columns to `devices`. These are captured
-- once at enrollment (and re-stamped on every heartbeat tick to catch
-- hardware swaps) so the Device Detail screen's "Hardware" card can render
-- CPU / RAM / storage numbers without a round-trip to heartbeat_logs.
--
-- Re-runnable. Every ALTER is guarded with IF NOT EXISTS.
-- =============================================================================

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS cpu_name       text,
  ADD COLUMN IF NOT EXISTS cpu_cores      int,
  ADD COLUMN IF NOT EXISTS architecture   text,
  ADD COLUMN IF NOT EXISTS total_ram_gb   numeric(7,2),
  ADD COLUMN IF NOT EXISTS disk_total_gb  numeric(10,2);

COMMENT ON COLUMN public.devices.cpu_name      IS 'Captured from Win32_Processor.Name at enrolment.';
COMMENT ON COLUMN public.devices.cpu_cores     IS 'NumberOfLogicalProcessors from Win32_Processor.';
COMMENT ON COLUMN public.devices.architecture  IS 'e.g. "64-bit" / "x64" from Win32_OperatingSystem.';
COMMENT ON COLUMN public.devices.total_ram_gb  IS 'TotalVisibleMemorySize from Win32_OperatingSystem, in GB.';
COMMENT ON COLUMN public.devices.disk_total_gb IS 'Primary fixed drive size, in GB.';
