-- =============================================================================
-- 8-enrollment-code.sql
-- -----------------------------------------------------------------------------
-- Adds the "one rolling org-level enrollment code" flow that replaces the
-- hard-coded `APP_ORG_SLUG` on the endpoint side.
--
-- * organizations gains `enrollment_code` + `enrollment_code_rotated_at`.
-- * A helper function `gen_enrollment_code()` emits a readable
--   `MSH-XXXX-YYYY` string that we seed + rotate from the Edge Function.
-- * Back-fills the seeded row so the existing Mistry & Shah organisation
--   immediately has a usable code after running this migration.
--
-- Re-runnable. Safe to apply on top of an existing deployment.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Readable 4+4 code generator.
-- ---------------------------------------------------------------------------
-- Excludes visually ambiguous characters (0/O, 1/I/L) so operators reading
-- a printout don't mistype. The `prefix` argument makes it trivial to brand
-- the code per-org in the future (`MSH-…`, `ACME-…`, etc.).
CREATE OR REPLACE FUNCTION public.gen_enrollment_code(prefix text DEFAULT 'MSH')
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  part1    text := '';
  part2    text := '';
  i        int;
BEGIN
  FOR i IN 1..4 LOOP
    part1 := part1 ||
      substr(alphabet,
             1 + floor(random() * length(alphabet))::int,
             1);
  END LOOP;
  FOR i IN 1..4 LOOP
    part2 := part2 ||
      substr(alphabet,
             1 + floor(random() * length(alphabet))::int,
             1);
  END LOOP;
  RETURN prefix || '-' || part1 || '-' || part2;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. organisations — new columns (idempotent).
-- ---------------------------------------------------------------------------
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS enrollment_code            text,
  ADD COLUMN IF NOT EXISTS enrollment_code_rotated_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS organizations_enrollment_code_uk
  ON public.organizations (enrollment_code)
  WHERE enrollment_code IS NOT NULL;

COMMENT ON COLUMN public.organizations.enrollment_code IS
  'Rolling code an endpoint enters on first run to attach itself to this tenant.';
COMMENT ON COLUMN public.organizations.enrollment_code_rotated_at IS
  'Last time an operator rotated the enrollment code.';

-- ---------------------------------------------------------------------------
-- 3. Back-fill any org that still has a NULL code.
-- ---------------------------------------------------------------------------
UPDATE public.organizations
   SET enrollment_code            = public.gen_enrollment_code('MSH'),
       enrollment_code_rotated_at = now()
 WHERE enrollment_code IS NULL;

-- ---------------------------------------------------------------------------
-- 4. RPC used by the rotate-enrollment-code Edge Function.
-- ---------------------------------------------------------------------------
-- Returns the fresh code + timestamp so the caller can round-trip a
-- single RPC instead of two UPDATEs.
CREATE OR REPLACE FUNCTION public.rotate_organization_enrollment_code(
  p_organization_id uuid,
  p_prefix          text DEFAULT 'MSH'
) RETURNS TABLE(enrollment_code text, rotated_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.organizations o
     SET enrollment_code            = public.gen_enrollment_code(p_prefix),
         enrollment_code_rotated_at = now()
   WHERE o.id = p_organization_id
  RETURNING o.enrollment_code, o.enrollment_code_rotated_at;
END;
$$;

-- Grant execute so the service-role key used by the Edge Function can
-- invoke the RPC. (service_role bypasses RLS but still needs EXECUTE.)
REVOKE ALL ON FUNCTION public.rotate_organization_enrollment_code(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rotate_organization_enrollment_code(uuid, text)
  TO service_role;
