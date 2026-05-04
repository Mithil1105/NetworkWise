import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../services/supabase_service_provider.dart';
import 'organization_service.dart';
import 'organization_summary.dart';

/// Singleton handle on the admin-scoped [OrganizationService].
final organizationServiceProvider = Provider<OrganizationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OrganizationService(client);
});

/// Reactive snapshot of the signed-in admin's organisation. Re-runs
/// whenever admin auth flips (sign-in, sign-out) so the Settings
/// screen always shows the right org.
class OrganizationSummaryNotifier extends AsyncNotifier<OrganizationSummary?> {
  @override
  Future<OrganizationSummary?> build() async {
    final auth = ref.watch(adminAuthProvider);

    // Only fetch once the auth controller has a concrete state.
    final status = auth.value?.status;
    if (status != AdminAuthStatus.signedIn) return null;

    final service = ref.read(organizationServiceProvider);
    return service.fetchCurrent();
  }

  /// Rotates the enrollment code via the Edge Function, then patches the
  /// summary in-place so the Settings screen updates without a full
  /// round-trip.
  Future<RotatedEnrollmentCode> rotateEnrollmentCode() async {
    final service = ref.read(organizationServiceProvider);
    final result = await service.rotateEnrollmentCode();

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          enrollmentCode: result.code,
          enrollmentCodeRotatedAt: result.rotatedAt,
        ),
      );
    } else {
      // Fallback — pull a fresh row if we didn't have one cached yet.
      final refreshed = await service.fetchCurrent();
      state = AsyncValue.data(refreshed);
    }
    return result;
  }

  /// Forces a re-read from PostgREST. Called from the UI when the
  /// operator presses "Refresh".
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(organizationServiceProvider);
      final summary = await service.fetchCurrent();
      state = AsyncValue.data(summary);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final organizationSummaryProvider =
    AsyncNotifierProvider<OrganizationSummaryNotifier, OrganizationSummary?>(
  OrganizationSummaryNotifier.new,
);
