import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessor over `.env` values.
///
/// Keeping this in a single file has two benefits:
///   1. Every call site has a compile-time symbol — typos turn into
///      analyzer errors instead of runtime `null`s.
///   2. The underlying dotenv plugin can be swapped out (for example,
///      for `--dart-define` in CI) without touching the rest of the app.
///
/// Values are read eagerly via getters so they always reflect the
/// current dotenv cache, but cached results are trivially cheap.
class Env {
  const Env._();

  /// Loads the `.env` file. Must be awaited before [Env] is read — do
  /// this once from `main.dart` before `runApp`.
  static Future<void> load({String fileName = '.env'}) async {
    await dotenv.load(fileName: fileName);
    _assertRequired();
  }

  // -------- Required --------

  /// Full Supabase project URL — e.g. `https://abcdxyz.supabase.co`.
  static String get supabaseUrl => _require('SUPABASE_URL');

  /// Public anon key. Safe to ship to the client because Row Level
  /// Security on every table governs what the key can actually do.
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  // -------- Optional --------

  /// Tenant slug — used by the device-registration Edge Function to
  /// attach a new endpoint to the right organisation.
  static String get orgSlug =>
      dotenv.maybeGet('APP_ORG_SLUG', fallback: '') ?? '';

  /// Environment label stamped on every heartbeat + alert.
  /// One of `development`, `staging`, `production`.
  static String get environment =>
      dotenv.maybeGet('APP_ENV', fallback: 'development') ?? 'development';

  /// `endpoint` (default) or `admin`. The endpoint role is what every
  /// monitored Windows PC runs — it enrolls, ships heartbeats, and
  /// renders the dashboard for its OWN machine only.
  ///
  /// The `admin` role adds a Supabase Auth sign-in gate on top and
  /// unlocks fleet-wide management UI (device rename, enrollment-code
  /// rotation, admin invites).
  static String get appRole =>
      (dotenv.maybeGet('APP_ROLE', fallback: 'endpoint') ?? 'endpoint')
          .toLowerCase()
          .trim();

  /// Convenience — the current install is the admin dashboard.
  static bool get isAdminRole => appRole == 'admin';

  /// Optional bootstrap override for heartbeat cadence. Falls back to
  /// the compile-time default if unset or malformed.
  static int? get heartbeatSecondsOverride {
    final raw = dotenv.maybeGet('APP_HEARTBEAT_SECONDS');
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  // -------- Internals --------

  static String _require(String key) {
    final v = dotenv.maybeGet(key);
    if (v == null || v.isEmpty) {
      throw StateError(
        'Missing required environment value: $key. '
        'Check your .env file (see .env.example).',
      );
    }
    return v;
  }

  static void _assertRequired() {
    // Touch the required getters once on startup so we fail fast with
    // a clear message rather than surfacing a cryptic null deep in the
    // Supabase client.
    // ignore: unused_local_variable
    final url = supabaseUrl;
    // ignore: unused_local_variable
    final key = supabaseAnonKey;
  }
}
