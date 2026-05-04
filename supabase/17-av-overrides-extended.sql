-- =============================================================================
-- 17-av-overrides-extended.sql
-- -----------------------------------------------------------------------------
-- Phase 23 — extend the existing per-AV override row from "license-only" to
-- "any field the probe couldn't reliably fetch". Quick Heal in particular is
-- inconsistent about exposing last-scan and definitions-date through the
-- standard Win32 channels, so we let the admin punch in those values
-- themselves and merge them on top of whatever the probe did capture.
--
-- The table was previously named `security_av_license_overrides`. We keep
-- the name (PostgREST callers + RLS policies depend on it) and just add
-- new nullable columns. License-only consumers still work — they just
-- ignore the extra columns.
--
-- Re-runnable. Every ALTER is guarded with IF NOT EXISTS.
-- =============================================================================

ALTER TABLE public.security_av_license_overrides
  ALTER COLUMN license_expires_at DROP NOT NULL;

ALTER TABLE public.security_av_license_overrides
  ADD COLUMN IF NOT EXISTS last_scan_at_override   timestamptz,
  ADD COLUMN IF NOT EXISTS definitions_date_override timestamptz,
  ADD COLUMN IF NOT EXISTS custom_status           text,
  ADD COLUMN IF NOT EXISTS engine_version          text;

COMMENT ON COLUMN public.security_av_license_overrides.last_scan_at_override   IS 'Admin-entered override for last scan time when the probe cannot read it.';
COMMENT ON COLUMN public.security_av_license_overrides.definitions_date_override IS 'Admin-entered override for AV signatures/definitions date.';
COMMENT ON COLUMN public.security_av_license_overrides.custom_status           IS 'Free-text status (e.g. "Verified manually 2026-04-15", "Awaiting renewal PO").';
COMMENT ON COLUMN public.security_av_license_overrides.engine_version          IS 'Admin-entered AV engine / product version string.';

-- The CHECK now permits a row where ONLY status / scan / engine are filled —
-- handy for "I just want to record I verified it manually today" without
-- having to make up a license expiry date.
ALTER TABLE public.security_av_license_overrides
  DROP CONSTRAINT IF EXISTS security_av_license_overrides_at_least_one;

ALTER TABLE public.security_av_license_overrides
  ADD CONSTRAINT security_av_license_overrides_at_least_one
  CHECK (
    license_expires_at        IS NOT NULL OR
    last_scan_at_override     IS NOT NULL OR
    definitions_date_override IS NOT NULL OR
    custom_status             IS NOT NULL OR
    engine_version            IS NOT NULL OR
    note                      IS NOT NULL
  );
