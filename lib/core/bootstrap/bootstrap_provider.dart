import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/supabase/supabase_repositories_providers.dart';
import '../services/data_service_provider.dart';
import '../services/device_identity_provider.dart';
import '../services/enrollment_provider.dart';
import '../services/system_probe/system_probe_provider.dart';
import 'device_bootstrap.dart';

/// Factory for the orchestrator. Kept separate from the state provider
/// so tests can override the composed repo without touching the
/// AsyncNotifier itself.
final deviceBootstrapProvider = Provider<DeviceBootstrap>((ref) {
  return DeviceBootstrap(
    identityService: ref.watch(deviceIdentityServiceProvider),
    devicesRepository: ref.watch(supabaseDevicesRepositoryProvider),
    enrollmentService: ref.watch(enrollmentServiceProvider),
    systemProbe: ref.watch(systemProbeProvider),
  );
});

/// Reactive handle on the bootstrap flow — read from the splash screen
/// to drive progress messaging. Invokes [DeviceBootstrap.run] exactly
/// once per ProviderScope; consumers can call `ref.invalidate` to force
/// a retry after a transient failure.
class BootstrapNotifier extends AsyncNotifier<BootstrapState> {
  @override
  Future<BootstrapState> build() async {
    final mode = ref.watch(dataSourceModeProvider);
    if (mode == DataSourceMode.mock) {
      // No bootstrap is needed when we are running against mock data.
      return const BootstrapState(phase: BootstrapPhase.ready);
    }

    final bootstrap = ref.watch(deviceBootstrapProvider);
    final result = await bootstrap.run();

    if (result.phase == BootstrapPhase.ready &&
        result.organizationId != null) {
      // Publish the org id so every repository query after this point
      // carries the `x-org-id` RLS header.
      ref.read(orgIdProvider.notifier).state = result.organizationId;
    }
    return result;
  }

  /// Force a re-run from the UI — e.g. after the operator fixes
  /// networking and taps "Retry" on the splash screen.
  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final bootstrapProvider =
    AsyncNotifierProvider<BootstrapNotifier, BootstrapState>(
  BootstrapNotifier.new,
);
