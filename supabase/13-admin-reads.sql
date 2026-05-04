-- =============================================================================
-- 13-admin-reads.sql
-- -----------------------------------------------------------------------------
-- Grants signed-in admins (role `authenticated` after a successful
-- auth.signInWithPassword) read access to the full fleet schema, scoped
-- to their organisation via current_admin_org_id().
--
-- The Phase 14/15 migrations focused on writes (devices_admin_update) and
-- organisation reads; without this file, an admin in the dashboard would
-- see zero devices/alerts because PostgREST switches to the authenticated
-- role once a JWT is attached to the client.
--
-- Re-runnable. Every policy uses DROP POLICY IF EXISTS + CREATE POLICY.
-- =============================================================================

-- devices
DROP POLICY IF EXISTS devices_admin_read ON public.devices;
CREATE POLICY devices_admin_read
  ON public.devices
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

-- network_adapters
DROP POLICY IF EXISTS network_adapters_admin_read ON public.network_adapters;
CREATE POLICY network_adapters_admin_read
  ON public.network_adapters
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

-- security_status
DROP POLICY IF EXISTS security_status_admin_read ON public.security_status;
CREATE POLICY security_status_admin_read
  ON public.security_status
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

-- alerts
DROP POLICY IF EXISTS alerts_admin_read ON public.alerts;
CREATE POLICY alerts_admin_read
  ON public.alerts
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

-- heartbeat_logs
DROP POLICY IF EXISTS heartbeat_logs_admin_read ON public.heartbeat_logs;
CREATE POLICY heartbeat_logs_admin_read
  ON public.heartbeat_logs
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());

-- app_settings
DROP POLICY IF EXISTS app_settings_admin_read ON public.app_settings;
CREATE POLICY app_settings_admin_read
  ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (organization_id = public.current_admin_org_id());
