import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_identity_service.dart';

/// Single instance of the identity service for the lifetime of the
/// ProviderScope.
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService();
});

/// Reactive snapshot of the current [DeviceIdentity]. `null` means the
/// endpoint has never been provisioned on this machine yet.
///
/// Kept as an [AsyncNotifier] so UI layers can show a splash / waiting
/// state on the very first launch while we persist the newly-minted
/// UUID to Windows Credential Manager.
class DeviceIdentityNotifier extends AsyncNotifier<DeviceIdentity?> {
  @override
  Future<DeviceIdentity?> build() async {
    final svc = ref.watch(deviceIdentityServiceProvider);
    return svc.load();
  }

  /// Provision a new UUID on this machine if none exists.
  Future<DeviceIdentity> ensureIdentity() async {
    final svc = ref.read(deviceIdentityServiceProvider);
    final id = await svc.ensureIdentity();
    state = AsyncValue.data(id);
    return id;
  }

  Future<void> markRegistered() async {
    final svc = ref.read(deviceIdentityServiceProvider);
    await svc.markRegistered();
    final reloaded = await svc.load();
    state = AsyncValue.data(reloaded);
  }

  Future<void> stampSync(DateTime when) async {
    final svc = ref.read(deviceIdentityServiceProvider);
    await svc.stampSync(when);
    final reloaded = await svc.load();
    state = AsyncValue.data(reloaded);
  }

  /// Factory-reset helper — clears the local identity entirely.
  Future<void> resetIdentity() async {
    final svc = ref.read(deviceIdentityServiceProvider);
    await svc.clear();
    state = const AsyncValue.data(null);
  }
}

final deviceIdentityProvider =
    AsyncNotifierProvider<DeviceIdentityNotifier, DeviceIdentity?>(
  DeviceIdentityNotifier.new,
);
