import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../repositories/i_devices_repository.dart';
import '../repositories/supabase/supabase_repositories_providers.dart';
import '../services/data_service_provider.dart';

/// Provides the [IDevicesRepository] the admin dashboard should use for
/// mutations. In Supabase mode we hand back the real Supabase repo; in
/// mock mode we throw at call time because there's no backing store to
/// mutate. The dialog UI gates itself on [Env.isAdminRole] + the data
/// source, so this throw should never fire in normal flows.
final adminDevicesRepositoryProvider = Provider<IDevicesRepository>((ref) {
  final mode = ref.watch(dataSourceModeProvider);
  switch (mode) {
    case DataSourceMode.supabase:
      return ref.watch(supabaseDevicesRepositoryProvider);
    case DataSourceMode.mock:
      throw StateError(
        'Device management writes are only available against a Supabase '
        'backend. Set APP_DATA_SOURCE=supabase to enable this flow.',
      );
  }
});

/// Thin wrapper that surfaces [IDevicesRepository.updateDevice] to the
/// UI. Keeping it in its own controller means the dialog doesn't have
/// to know about the repository abstraction.
class DeviceAdminController {
  DeviceAdminController(this._ref);

  final Ref _ref;

  Future<Device> updateDevice({
    required String deviceId,
    String? hostnameLabel,
    String? assignedUser,
    String? location,
    List<String>? tags,
    bool? archived,
  }) {
    final repo = _ref.read(adminDevicesRepositoryProvider);
    return repo.updateDevice(
      deviceId: deviceId,
      hostnameLabel: hostnameLabel,
      assignedUser: assignedUser,
      location: location,
      tags: tags,
      archived: archived,
    );
  }
}

final deviceAdminControllerProvider = Provider<DeviceAdminController>((ref) {
  return DeviceAdminController(ref);
});
