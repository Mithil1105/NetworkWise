-- =============================================================================
-- 7-seed.sql
-- -----------------------------------------------------------------------------
-- Optional seed data — populates the "Mistry & Shah" organisation so
-- the Flutter app has something to read against on first launch.
-- Safe to re-run; every insert is guarded by ON CONFLICT.
-- =============================================================================

INSERT INTO public.organizations (slug, name, description)
VALUES (
  'mistry-and-shah',
  'Mistry & Shah',
  'Chartered Accountants — primary production tenant.'
)
ON CONFLICT (slug) DO UPDATE
  SET name        = EXCLUDED.name,
      description = EXCLUDED.description;

-- Org-wide settings default — used when a device does not have a
-- specific row in app_settings yet. device_id IS NULL flags this as
-- the fallback.
INSERT INTO public.app_settings (
  organization_id, device_id, theme_mode, heartbeat_seconds,
  storage_threshold_percent, cpu_warning_percent, memory_warning_percent
)
SELECT
  o.id, NULL, 'light', 30, 85.00, 80.00, 85.00
FROM public.organizations o
WHERE o.slug = 'mistry-and-shah'
ON CONFLICT (organization_id, device_id) DO NOTHING;
