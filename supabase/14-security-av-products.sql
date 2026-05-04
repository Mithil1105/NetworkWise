-- -----------------------------------------------------------------------------
-- Phase 18 — multi-AV inventory + license expiry
-- -----------------------------------------------------------------------------
-- Historically `security_status` carried a single antivirus_name column,
-- which works for Defender-only shops but falls apart on machines that
-- run Defender alongside Kaspersky / Quick Heal / Bitdefender / Norton
-- / McAfee. This migration introduces:
--
--   * security_antivirus_products
--         One row per AV engine currently installed on a device.
--         Populated by the `report-snapshot` Edge Function from the
--         Windows Security Center probe (WMI root\SecurityCenter2
--         AntiVirusProduct). REPLACED wholesale on every snapshot so
--         uninstalls fall off immediately.
--
--   * security_av_license_overrides
--         Admin-entered license expiry dates. These take precedence
--         over anything the probe picks up from vendor registry keys
--         — useful when a vendor doesn't expose the date at all, or
--         when the chartered accountancy firm wants to track a
--         purchase-date renewal that the engine itself isn't aware of.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.security_antivirus_products (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id               uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  organization_id         uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  display_name            text NOT NULL,
  product_id              text,

  is_primary              boolean NOT NULL DEFAULT false,
  is_enabled              boolean NOT NULL DEFAULT false,
  is_up_to_date           boolean NOT NULL DEFAULT false,
  real_time_protection    boolean NOT NULL DEFAULT false,
  last_scan_at            timestamptz,

  license_expires_at      timestamptz,
  license_source          text NOT NULL DEFAULT 'unknown'
                          CHECK (license_source IN ('wsc','registry','manual','unknown')),

  observed_at             timestamptz NOT NULL DEFAULT now(),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sec_av_products_device
  ON public.security_antivirus_products (device_id);
CREATE INDEX IF NOT EXISTS idx_sec_av_products_org
  ON public.security_antivirus_products (organization_id);
CREATE INDEX IF NOT EXISTS idx_sec_av_products_expiry
  ON public.security_antivirus_products (license_expires_at)
  WHERE license_expires_at IS NOT NULL;

-- Trigger: bump updated_at on every UPDATE.
DROP TRIGGER IF EXISTS trg_sec_av_products_touch
  ON public.security_antivirus_products;
CREATE TRIGGER trg_sec_av_products_touch
  BEFORE UPDATE ON public.security_antivirus_products
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- Admin manual license override — keyed by device + display_name so the
-- admin can pin an expiry date onto a specific AV engine without having
-- to know the probe's internal product_id.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.security_av_license_overrides (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id               uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  organization_id         uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,

  display_name            text NOT NULL,
  license_expires_at      timestamptz NOT NULL,
  note                    text,

  set_by_user_id          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  set_at                  timestamptz NOT NULL DEFAULT now(),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),

  UNIQUE (device_id, display_name)
);

CREATE INDEX IF NOT EXISTS idx_sec_av_overrides_device
  ON public.security_av_license_overrides (device_id);
CREATE INDEX IF NOT EXISTS idx_sec_av_overrides_org
  ON public.security_av_license_overrides (organization_id);

DROP TRIGGER IF EXISTS trg_sec_av_overrides_touch
  ON public.security_av_license_overrides;
CREATE TRIGGER trg_sec_av_overrides_touch
  BEFORE UPDATE ON public.security_av_license_overrides
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- RLS — same pattern as every other per-org table:
--   * endpoint role reads/writes only its own device (registration_secret
--     is verified by the Edge Function, which uses the service-role key
--     and therefore bypasses RLS anyway),
--   * admin role reads/writes any row scoped to their current
--     organization via `current_admin_org_id()`.
-- -----------------------------------------------------------------------------
ALTER TABLE public.security_antivirus_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_av_license_overrides ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sec_av_products_read_admin
  ON public.security_antivirus_products;
CREATE POLICY sec_av_products_read_admin
  ON public.security_antivirus_products
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

DROP POLICY IF EXISTS sec_av_products_read_endpoint
  ON public.security_antivirus_products;
CREATE POLICY sec_av_products_read_endpoint
  ON public.security_antivirus_products
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

DROP POLICY IF EXISTS sec_av_overrides_read_admin
  ON public.security_av_license_overrides;
CREATE POLICY sec_av_overrides_read_admin
  ON public.security_av_license_overrides
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

DROP POLICY IF EXISTS sec_av_overrides_write_admin
  ON public.security_av_license_overrides;
CREATE POLICY sec_av_overrides_write_admin
  ON public.security_av_license_overrides
  FOR ALL
  TO authenticated
  USING (organization_id = public.current_admin_org_id())
  WITH CHECK (organization_id = public.current_admin_org_id());
