-- =============================================================================
-- 6-rls-policies.sql
-- -----------------------------------------------------------------------------
-- Starter RLS policies. Design intent:
--
--   1. service_role has full access by default (Supabase bypass) — this
--      is how every Edge Function performs privileged writes.
--
--   2. anon role (the Flutter app's runtime role, using SUPABASE_ANON_KEY)
--      gets SELECT-only access, scoped to its organisation.
--      The Flutter app sends its organization id in the `x-org-id`
--      HTTP header on every request; RLS checks that header matches
--      the row's organization_id.
--
--   3. All write paths (INSERT / UPDATE / DELETE) for anon are DENIED.
--      Endpoints report data exclusively through Edge Functions.
--
--   4. `authenticated` role is reserved for the future dashboard user
--      story — policies for it are sketched out but left commented.
--
-- Helper:
--   request_header(name) — returns a given request header as text or NULL.
-- =============================================================================

-- ---- helpers -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_header(name text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    current_setting('request.headers', true)::json ->> lower(name),
    ''
  );
$$;

CREATE OR REPLACE FUNCTION public.current_org_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(public.request_header('x-org-id'), '')::uuid;
$$;

-- =============================================================================
-- Drop any existing named policies so this file is fully re-runnable.
-- =============================================================================
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'organizations','devices','network_adapters','security_status',
    'alerts','heartbeat_logs','app_settings'
  ] LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS "anon read %1$s" ON public.%1$I;', t
    );
  END LOOP;
END$$;

-- =============================================================================
-- anon SELECT — scoped by x-org-id header
-- =============================================================================

-- organizations: allow anon to read its own org row so the Flutter app
-- can display org name / slug on the About card.
CREATE POLICY "anon read organizations"
  ON public.organizations
  FOR SELECT
  TO anon
  USING (id = public.current_org_id());

-- devices
CREATE POLICY "anon read devices"
  ON public.devices
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- network_adapters
CREATE POLICY "anon read network_adapters"
  ON public.network_adapters
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- security_status
CREATE POLICY "anon read security_status"
  ON public.security_status
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- alerts
CREATE POLICY "anon read alerts"
  ON public.alerts
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- heartbeat_logs — optional for the Flutter app (mostly for dashboards);
-- read allowed only if the caller is in the same org.
CREATE POLICY "anon read heartbeat_logs"
  ON public.heartbeat_logs
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- app_settings: allow the device to read its own settings row AND the
-- org-wide default (device_id IS NULL).
CREATE POLICY "anon read app_settings"
  ON public.app_settings
  FOR SELECT
  TO anon
  USING (organization_id = public.current_org_id());

-- =============================================================================
-- Writes for anon — intentionally NONE.
-- Every INSERT / UPDATE / DELETE must go through an Edge Function
-- using the service_role key. See:
--   supabase/functions/register-device/index.ts
--   supabase/functions/report-heartbeat/index.ts
--   supabase/functions/report-snapshot/index.ts
--   supabase/functions/report-alert/index.ts
--   supabase/functions/update-alert-status/index.ts
-- =============================================================================

-- =============================================================================
-- FUTURE — authenticated dashboard users (Phase B)
-- -----------------------------------------------------------------------------
-- When the admin console goes live, create an `organization_memberships`
-- table keyed off auth.uid() and add policies like the template below.
-- Leaving this as comments so the intent is captured next to the
-- starter policies.
-- =============================================================================
--
-- CREATE TABLE IF NOT EXISTS public.organization_memberships (
--   user_id         uuid REFERENCES auth.users(id) ON DELETE CASCADE,
--   organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
--   role            text NOT NULL DEFAULT 'member'
--                   CHECK (role IN ('owner','admin','member','viewer')),
--   created_at      timestamptz NOT NULL DEFAULT now(),
--   PRIMARY KEY (user_id, organization_id)
-- );
--
-- CREATE POLICY "member read devices"
--   ON public.devices
--   FOR SELECT
--   TO authenticated
--   USING (EXISTS (
--     SELECT 1 FROM public.organization_memberships m
--     WHERE m.user_id = auth.uid()
--       AND m.organization_id = devices.organization_id
--   ));
--
-- Add SELECT / UPDATE / DELETE variations per table with stricter role
-- checks (only `owner`/`admin` can DELETE etc).
