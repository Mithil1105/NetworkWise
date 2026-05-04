-- =============================================================================
-- 10-seed-admin.sql
-- -----------------------------------------------------------------------------
-- HOW TO SEED THE FIRST ADMIN USER
-- -----------------------------------------------------------------------------
-- Supabase Auth stores user rows in `auth.users`, but signup via SQL is
-- discouraged because the password hash has to match the exact bcrypt
-- format the gotrue service uses. Use ONE of these two paths instead:
--
--   A)  Preferred — Dashboard ▸ Authentication ▸ Users ▸ "Invite user"
--       or "Add user" (email + password). Copy the new user's UUID and
--       paste it into the INSERT below.
--
--   B)  CLI — `supabase auth admin create-user --email x --password y`
--       (requires SUPABASE_ACCESS_TOKEN).
--
-- After the auth row exists, this script links it to the
-- `mistry-and-shah` organisation so RLS policies pick up the admin.
-- =============================================================================

-- 1. Replace the UUID below with the one you just created in Auth.
--    Leave the email here as a sanity check — the block aborts if the
--    UUID does not resolve to the matching email.
--
-- 2. Run this whole file in the SQL Editor.

DO $$
DECLARE
  v_user_id  uuid := '00000000-0000-0000-0000-000000000000'; -- <-- REPLACE
  v_email    text := 'admin@mistryandshah.com';              -- <-- REPLACE
  v_org_id   uuid;
  v_found    text;
BEGIN
  IF v_user_id = '00000000-0000-0000-0000-000000000000' THEN
    RAISE EXCEPTION 'Edit 10-seed-admin.sql: set v_user_id to the auth.users.id of the admin you created.';
  END IF;

  SELECT email INTO v_found FROM auth.users WHERE id = v_user_id;
  IF v_found IS NULL THEN
    RAISE EXCEPTION 'No auth.users row for %; create the user first.', v_user_id;
  END IF;
  IF v_found <> v_email THEN
    RAISE EXCEPTION 'UUID % is bound to % but script expected %.',
      v_user_id, v_found, v_email;
  END IF;

  SELECT id INTO v_org_id
    FROM public.organizations
   WHERE slug = 'mistry-and-shah';
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'Run 7-seed.sql first — organisation mistry-and-shah is missing.';
  END IF;

  INSERT INTO public.admin_members (user_id, organization_id, role, full_name)
  VALUES (v_user_id, v_org_id, 'owner', 'Admin — Mistry & Shah')
  ON CONFLICT (user_id) DO UPDATE
    SET organization_id = EXCLUDED.organization_id,
        role            = EXCLUDED.role,
        full_name       = EXCLUDED.full_name,
        updated_at      = now();
END
$$;
