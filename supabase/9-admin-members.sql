-- =============================================================================
-- 9-admin-members.sql
-- -----------------------------------------------------------------------------
-- Links Supabase Auth users to organisations for the admin dashboard.
--
-- Phase 15 adds *admin* identities only. Endpoint (device-side) access
-- still flows through the anon key + `x-org-id` header; admins on the
-- dashboard authenticate with email + password via Supabase Auth.
--
-- Re-runnable. Safe to apply alongside existing data.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_members (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  organization_id  uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  role             text NOT NULL DEFAULT 'admin'
                   CHECK (role IN ('admin','owner')),
  full_name        text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_members_org_idx
  ON public.admin_members (organization_id);

-- -----------------------------------------------------------------------------
-- Helper — returns the caller's org id from their admin_members row.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_admin_org_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT organization_id
    FROM public.admin_members
   WHERE user_id = auth.uid()
   LIMIT 1;
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.admin_members ENABLE ROW LEVEL SECURITY;

-- Admin can see their own row (and therefore discover their org).
DROP POLICY IF EXISTS admin_members_read ON public.admin_members;
CREATE POLICY admin_members_read
  ON public.admin_members
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Admin-write policies on the rest of the schema.
-- -----------------------------------------------------------------------------
-- These policies live here (not in 6-rls-policies.sql) because they
-- depend on `admin_members`, which did not exist until Phase 15.

-- Devices — admins can UPDATE rows that belong to their org (rename,
-- archive, set assignee, etc.) but not INSERT or DELETE (device rows
-- are only created by the register-device Edge Function).
DROP POLICY IF EXISTS devices_admin_update ON public.devices;
CREATE POLICY devices_admin_update
  ON public.devices
  FOR UPDATE
  TO authenticated
  USING      (organization_id = public.current_admin_org_id())
  WITH CHECK (organization_id = public.current_admin_org_id());

-- Organisations — admins can read their own row (so the Settings
-- screen can render the enrollment code).
DROP POLICY IF EXISTS organizations_admin_read ON public.organizations;
CREATE POLICY organizations_admin_read
  ON public.organizations
  FOR SELECT
  TO authenticated
  USING (id = public.current_admin_org_id());
