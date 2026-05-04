import 'package:supabase_flutter/supabase_flutter.dart';

/// Central choke-point that stamps every PostgREST request with
/// `x-org-id` — the header that the Row Level Security policies in
/// `supabase/6-rls-policies.sql` use to scope reads.
///
/// The Flutter app resolves the organization's UUID once on bootstrap
/// (by looking up `APP_ORG_SLUG` against the `organizations` table
/// via the `register-device` Edge Function), then calls
/// [applyOrganization] so every subsequent `client.from('...')` call
/// inherits the header automatically.
class SupabaseHeaders {
  const SupabaseHeaders._();

  /// Mutates the shared PostgREST client to include `x-org-id` on
  /// every request. Repositories do not need to pass the header
  /// explicitly — they simply read from `client.from('...')`.
  static void applyOrganization(SupabaseClient client, String orgId) {
    if (orgId.isEmpty) {
      client.rest.headers.remove('x-org-id');
      return;
    }
    client.rest.headers['x-org-id'] = orgId;
  }

  /// Returns the currently-applied org id, if any.
  static String? currentOrgId(SupabaseClient client) {
    return client.rest.headers['x-org-id'];
  }
}
