-- =============================================================================
-- 1-extensions.sql
-- -----------------------------------------------------------------------------
-- Run FIRST. Enables the Postgres extensions we need and installs the
-- shared trigger function used by every table that has an `updated_at`
-- column. Safe to re-run — every statement is guarded by IF NOT EXISTS
-- or CREATE OR REPLACE.
-- =============================================================================

-- Strong UUID generator used by `gen_random_uuid()` in default clauses.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- citext — case-insensitive text. Useful for the organisation slug so
-- "Mistry-And-Shah" and "mistry-and-shah" resolve to the same row.
CREATE EXTENSION IF NOT EXISTS citext;

-- -----------------------------------------------------------------------------
-- touch_updated_at()
-- -----------------------------------------------------------------------------
-- Generic BEFORE UPDATE trigger that sets NEW.updated_at := now().
-- Attached to mutable tables from 4-triggers.sql.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
