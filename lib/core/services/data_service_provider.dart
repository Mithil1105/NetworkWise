import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/supabase/supabase_repositories_providers.dart';
import 'device_identity_provider.dart';
import 'i_data_service.dart';
import 'mock_data_service.dart';
import 'supabase_data_service.dart';

/// Configures how the app should source its fleet data.
///
/// The choice is made at boot time from two signals:
///   1. the `.env` flag `APP_DATA_SOURCE=mock|supabase` (authoritative);
///   2. if unset, the Supabase client is used when `SUPABASE_URL` + anon
///      key are present, and the mock is used otherwise.
enum DataSourceMode { mock, supabase }

/// Exposed as a provider so tests / golden scripts can force `mock`
/// even when a `.env` file is present on disk.
final dataSourceModeProvider = Provider<DataSourceMode>((ref) {
  final raw = dotenv.maybeGet('APP_DATA_SOURCE')?.toLowerCase();
  switch (raw) {
    case 'mock':
      return DataSourceMode.mock;
    case 'supabase':
      return DataSourceMode.supabase;
    default:
      // Derive from presence of Supabase env vars.
      final hasSupabase =
          (dotenv.maybeGet('SUPABASE_URL')?.isNotEmpty ?? false) &&
              (dotenv.maybeGet('SUPABASE_ANON_KEY')?.isNotEmpty ?? false);
      return hasSupabase ? DataSourceMode.supabase : DataSourceMode.mock;
  }
});

/// Global data service handle.
///
/// In `mock` mode this is the in-memory [MockDataService]; in
/// `supabase` mode it is the repository-backed [SupabaseDataService].
/// Switching modes is as simple as toggling `APP_DATA_SOURCE` in
/// `.env` and restarting — no widget code has to change.
final dataServiceProvider = Provider<IDataService>((ref) {
  final mode = ref.watch(dataSourceModeProvider);

  final IDataService service;
  switch (mode) {
    case DataSourceMode.supabase:
      // Materialise the org-header side-effect so every PostgREST call
      // after this point is correctly scoped.
      ref.watch(supabaseOrgHeaderBinderProvider);

      service = SupabaseDataService(
        devicesRepo: ref.watch(supabaseDevicesRepositoryProvider),
        alertsRepo: ref.watch(supabaseAlertsRepositoryProvider),
        securityRepo: ref.watch(supabaseSecurityRepositoryProvider),
        adaptersRepo: ref.watch(supabaseNetworkAdaptersRepositoryProvider),
        heartbeatRepo: ref.watch(supabaseHeartbeatRepositoryProvider),
        identityService: ref.watch(deviceIdentityServiceProvider),
      );
      break;
    case DataSourceMode.mock:
      service = MockDataService();
      break;
  }

  // Fire-and-forget — start() primes internal state; awaiting it would
  // force every consumer into an AsyncValue for no UX gain.
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
