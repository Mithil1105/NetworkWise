import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service_provider.dart';
import '../i_alerts_repository.dart';
import '../i_app_settings_repository.dart';
import '../i_devices_repository.dart';
import '../i_heartbeat_repository.dart';
import '../i_network_adapters_repository.dart';
import '../i_security_repository.dart';
import 'supabase_activity_repository.dart';
import 'supabase_alerts_repository.dart';
import 'supabase_app_settings_repository.dart';
import 'supabase_devices_repository.dart';
import 'supabase_headers.dart';
import 'supabase_heartbeat_repository.dart';
import 'supabase_network_adapters_repository.dart';
import 'supabase_security_repository.dart';

/// Currently-active organization UUID, resolved from the
/// `organizations.slug` on bootstrap. Null means "bootstrap has not
/// run yet" — repositories still build, but RLS will return zero rows
/// until this is populated.
final orgIdProvider = StateProvider<String?>((ref) => null);

/// Registers the org-id into the shared PostgREST headers whenever it
/// changes. Reading this provider once in `main.dart` (via
/// `ref.listen`) wires the side-effect for the entire app lifetime.
final supabaseOrgHeaderBinderProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.listen<String?>(orgIdProvider, (prev, next) {
    SupabaseHeaders.applyOrganization(client, next ?? '');
  }, fireImmediately: true);
});

// -------- Concrete repository providers --------

final supabaseDevicesRepositoryProvider = Provider<IDevicesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseDevicesRepository(client);
});

final supabaseNetworkAdaptersRepositoryProvider =
    Provider<INetworkAdaptersRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseNetworkAdaptersRepository(client);
});

final supabaseSecurityRepositoryProvider = Provider<ISecurityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSecurityRepository(client);
});

final supabaseAlertsRepositoryProvider = Provider<IAlertsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAlertsRepository(client);
});

final supabaseHeartbeatRepositoryProvider =
    Provider<IHeartbeatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseHeartbeatRepository(client);
});

final supabaseAppSettingsRepositoryProvider =
    Provider<IAppSettingsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAppSettingsRepository(client);
});

/// Phase 22 — derives screen-time + per-app minutes from heartbeat_logs.
/// Lives next to the rest of the Supabase repos so the org-id header
/// binding above applies automatically.
final supabaseActivityRepositoryProvider =
    Provider<SupabaseActivityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseActivityRepository(client);
});
