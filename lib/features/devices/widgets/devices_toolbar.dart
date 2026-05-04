import 'package:flutter/material.dart';

import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';
import 'add_device_dialog.dart';

/// Search field + status filter dropdown + result count. Purely
/// presentational — state owned by the parent screen.
class DevicesToolbar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final DeviceStatus? statusFilter; // null = All
  final ValueChanged<DeviceStatus?> onStatusFilterChanged;
  final bool showArchived;
  final ValueChanged<bool> onShowArchivedChanged;
  final int archivedCount;
  final int visibleCount;
  final int totalCount;

  const DevicesToolbar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.showArchived,
    required this.onShowArchivedChanged,
    required this.archivedCount,
    required this.visibleCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search hostname, IP or user…',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      splashRadius: 16,
                      onPressed: () => onSearchChanged(''),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DeviceStatus?>(
              value: statusFilter,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              isDense: true,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(
                    value: DeviceStatus.online, child: Text('Online')),
                DropdownMenuItem(
                    value: DeviceStatus.offline, child: Text('Offline')),
                DropdownMenuItem(
                    value: DeviceStatus.warning, child: Text('Warning')),
              ],
              onChanged: onStatusFilterChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _ArchivedToggle(
          showArchived: showArchived,
          archivedCount: archivedCount,
          onChanged: onShowArchivedChanged,
        ),
        const Spacer(),
        _CountPill(visible: visibleCount, total: totalCount),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => showAddDeviceDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add device'),
          style: FilledButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchivedToggle extends StatelessWidget {
  final bool showArchived;
  final int archivedCount;
  final ValueChanged<bool> onChanged;

  const _ArchivedToggle({
    required this.showArchived,
    required this.archivedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!showArchived),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              showArchived ? Icons.visibility : Icons.visibility_off_outlined,
              size: 16,
              color: AppColors.neutral,
            ),
            const SizedBox(width: 6),
            Text(
              showArchived
                  ? 'Including archived'
                  : 'Hide archived${archivedCount > 0 ? ' ($archivedCount)' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int visible;
  final int total;
  const _CountPill({required this.visible, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visible == total
            ? '$total devices'
            : 'Showing $visible of $total',
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.info,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
