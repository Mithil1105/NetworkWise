-- =============================================================================
-- 5-rls-enable.sql
-- -----------------------------------------------------------------------------
-- Turns Row Level Security on for every table AND forces it for table
-- owners too. Without FORCE, the table owner silently bypasses RLS —
-- easy to overlook, dangerous in a migration-heavy environment.
-- After this file runs, NO role except `service_role` can read or
-- write anything until 6-rls-policies.sql grants explicit access.
-- =============================================================================

ALTER TABLE public.organizations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations    FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.devices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices          FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.network_adapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.network_adapters FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.security_status  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_status  FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.alerts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts           FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.heartbeat_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heartbeat_logs   FORCE  ROW LEVEL SECURITY;

ALTER TABLE public.app_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings     FORCE  ROW LEVEL SECURITY;
