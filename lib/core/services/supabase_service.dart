import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper around the global [Supabase] singleton.
///
/// Centralising access through this class gives us three things:
///   1. A single, test-replaceable handle on the [SupabaseClient].
///   2. A compile-time guarantee that `Supabase.initialize(...)` has
///      been called — the constructor throws otherwise.
///   3. A natural place to hang future concerns (telemetry hooks, retry
///      wrappers, Edge Function helpers).
class SupabaseService {
  SupabaseService() {
    // Will throw `_Uninitialized` if we ever forget to call
    // [SupabaseService.initialize] from `main.dart`.
    _client = Supabase.instance.client;
  }

  late final SupabaseClient _client;

  /// Raw client — exposed for repositories and Edge-Function calls.
  SupabaseClient get client => _client;

  /// Current environment label (development / staging / production).
  String get environment => Env.environment;

  /// Tenant slug from `.env` — empty if unconfigured.
  String get orgSlug => Env.orgSlug;

  // ------------------------------------------------------------------
  // One-time initialisation — invoked from `main.dart` BEFORE runApp.
  // ------------------------------------------------------------------

  /// Initialises the underlying Supabase SDK. Idempotent-safe: calling
  /// it twice is a no-op because `Supabase.initialize` itself guards
  /// against double init.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      // Admin dashboard sessions sign in via email + password and need
      // the refresh flow. Endpoint telemetry goes through the anon key
      // directly and is unaffected by this toggle.
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
      ),
      debug: false,
    );
  }
}
