-- =============================================================================
-- 11-device-admin.sql
-- -----------------------------------------------------------------------------
-- Phase 16 — Device management
--
-- Adds the columns that let admins rename a device (display label, as
-- distinct from the Windows hostname) and archive/un-enroll it without
-- losing the row (archived devices still carry their heartbeat history
-- for audit purposes).
--
-- Re-runnable. Safe to apply on top of existing data.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Friendly display label (admin-assigned, falls back to `hostname`).
-- -----------------------------------------------------------------------------
ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS hostname_label text;

COMMENT ON COLUMN public.devices.hostname_label IS
  'Admin-assigned friendly label. Falls back to `hostname` when NULL. Does not affect uniqueness — the (organization_id, hostname) unique constraint still gates provisioning.';

-- -----------------------------------------------------------------------------
-- Archive flag. NULL means "active"; a timestamp means "archived at <ts>".
-- -----------------------------------------------------------------------------
ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

COMMENT ON COLUMN public.devices.archived_at IS
  'Soft-delete marker. Archived devices are hidden from the default Devices list but keep their heartbeat_logs rows for audit.';

CREATE INDEX IF NOT EXISTS devices_archived_at_idx
  ON public.devices (organization_id, archived_at);

-- -----------------------------------------------------------------------------
-- No new RLS policies are needed — `devices_admin_update` from
-- 9-admin-members.sql already covers these columns because it matches
-- on `organization_id = public.current_admin_org_id()` for all UPDATEs.
-- -----------------------------------------------------------------------------
