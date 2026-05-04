import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/devices_provider.dart';
import 'device_detail_screen.dart';
import 'widgets/devices_table.dart';
import 'widgets/devices_toolbar.dart';

/// Devices list — search, status filter, column sort and master-detail
/// navigation, with every piece of shared state backed by Riverpod.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDeviceProvider);
    if (selected != null) {
      return DeviceDetailScreen(
        device: selected,
        onBack: () =>
            ref.read(selectedDeviceIdProvider.notifier).state = null,
      );
    }

    final devices = ref.watch(devicesProvider);
    final visible = ref.watch(filteredSortedDevicesProvider);
    final search = ref.watch(deviceSearchProvider);
    final statusFilter = ref.watch(deviceStatusFilterProvider);
    final sortColumn = ref.watch(deviceSortColumnProvider);
    final sortDirection = ref.watch(deviceSortDirectionProvider);
    final showArchived = ref.watch(showArchivedDevicesProvider);
    final archivedCount = ref.watch(archivedDevicesCountProvider);

    void onSort(DeviceSortColumn col) {
      if (sortColumn == col) {
        ref.read(deviceSortDirectionProvider.notifier).state =
            sortDirection == SortDirection.ascending
                ? SortDirection.descending
                : SortDirection.ascending;
      } else {
        ref.read(deviceSortColumnProvider.notifier).state = col;
        ref.read(deviceSortDirectionProvider.notifier).state =
            SortDirection.ascending;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DevicesToolbar(
            searchQuery: search,
            onSearchChanged: (v) =>
                ref.read(deviceSearchProvider.notifier).state = v,
            statusFilter: statusFilter,
            onStatusFilterChanged: (v) =>
                ref.read(deviceStatusFilterProvider.notifier).state = v,
            showArchived: showArchived,
            onShowArchivedChanged: (v) =>
                ref.read(showArchivedDevicesProvider.notifier).state = v,
            archivedCount: archivedCount,
            visibleCount: visible.length,
            totalCount: devices.length,
          ),
          const SizedBox(height: 16),
          DevicesTable(
            devices: visible,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
            onRowTap: (d) =>
                ref.read(selectedDeviceIdProvider.notifier).state = d.id,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
