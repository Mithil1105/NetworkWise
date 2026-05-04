import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/devices/widgets/devices_table.dart'
    show DeviceSortColumn, SortDirection;
import '../models/device.dart';
import '../services/data_service_provider.dart';

/// Notifier that mirrors the fleet snapshot from [IDataService]. It
/// subscribes to the service's `changes` broadcast in `build` and
/// re-reads on every tick, so the UI sees a fresh list every time the
/// heartbeat fires or a mutation occurs.
class DevicesNotifier extends Notifier<List<Device>> {
  @override
  List<Device> build() {
    final service = ref.watch(dataServiceProvider);
    final sub = service.changes.listen((_) {
      state = service.getDevices();
    });
    ref.onDispose(sub.cancel);
    return service.getDevices();
  }
}

final devicesProvider =
    NotifierProvider<DevicesNotifier, List<Device>>(DevicesNotifier.new);

// ---------------- filter / sort / selection state ----------------

final deviceSearchProvider = StateProvider<String>((ref) => '');

final deviceStatusFilterProvider =
    StateProvider<DeviceStatus?>((ref) => null);

/// Whether archived / un-enrolled devices are shown in the table.
/// Defaults to hidden — admins flip it on to restore a device.
final showArchivedDevicesProvider = StateProvider<bool>((ref) => false);

final deviceSortColumnProvider =
    StateProvider<DeviceSortColumn>((ref) => DeviceSortColumn.hostname);

final deviceSortDirectionProvider =
    StateProvider<SortDirection>((ref) => SortDirection.ascending);

final selectedDeviceIdProvider = StateProvider<String?>((ref) => null);

// ---------------- derived ----------------

/// The devices list as the user currently sees it — search, status and
/// column sort all applied. Any change upstream triggers exactly one
/// recomputation here.
final filteredSortedDevicesProvider = Provider<List<Device>>((ref) {
  final devices = ref.watch(devicesProvider);
  final search = ref.watch(deviceSearchProvider).trim().toLowerCase();
  final statusFilter = ref.watch(deviceStatusFilterProvider);
  final column = ref.watch(deviceSortColumnProvider);
  final direction = ref.watch(deviceSortDirectionProvider);
  final showArchived = ref.watch(showArchivedDevicesProvider);

  var list = devices.where((d) {
    if (!showArchived && d.isArchived) return false;
    if (statusFilter != null && d.status != statusFilter) return false;
    if (search.isEmpty) return true;
    return d.hostname.toLowerCase().contains(search) ||
        d.hostnameLabel.toLowerCase().contains(search) ||
        d.ipAddress.toLowerCase().contains(search) ||
        d.assignedUser.toLowerCase().contains(search) ||
        d.location.toLowerCase().contains(search) ||
        d.tags.any((t) => t.toLowerCase().contains(search)) ||
        d.os.toLowerCase().contains(search);
  }).toList();

  list.sort((a, b) {
    int cmp;
    switch (column) {
      case DeviceSortColumn.hostname:
        cmp = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
        break;
      case DeviceSortColumn.ipAddress:
        cmp = a.ipAddress.compareTo(b.ipAddress);
        break;
      case DeviceSortColumn.os:
        cmp = a.os.compareTo(b.os);
        break;
      case DeviceSortColumn.user:
        cmp = a.assignedUser.compareTo(b.assignedUser);
        break;
      case DeviceSortColumn.status:
        cmp = a.status.index.compareTo(b.status.index);
        break;
      case DeviceSortColumn.health:
        cmp = a.health.index.compareTo(b.health.index);
        break;
      case DeviceSortColumn.lastSeen:
        cmp = a.lastSeen.compareTo(b.lastSeen);
        break;
    }
    return direction == SortDirection.ascending ? cmp : -cmp;
  });

  return list;
});

/// Count of archived devices — used by the toolbar toggle label.
final archivedDevicesCountProvider = Provider<int>((ref) {
  final devices = ref.watch(devicesProvider);
  var count = 0;
  for (final d in devices) {
    if (d.isArchived) count++;
  }
  return count;
});

/// Resolves the currently selected device, or `null` when the list is
/// being shown instead of a detail page.
final selectedDeviceProvider = Provider<Device?>((ref) {
  final id = ref.watch(selectedDeviceIdProvider);
  if (id == null) return null;
  final devices = ref.watch(devicesProvider);
  for (final d in devices) {
    if (d.id == id) return d;
  }
  return null;
});
