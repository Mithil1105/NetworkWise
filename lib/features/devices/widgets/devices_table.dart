import 'package:flutter/material.dart';

import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import 'active_window_chip.dart';
import 'device_health_chip.dart';
import 'device_status_chip.dart';

enum DeviceSortColumn { hostname, ipAddress, os, user, status, health, lastSeen }

/// Which way a column is sorted.
enum SortDirection { ascending, descending }

class DevicesTable extends StatelessWidget {
  final List<Device> devices;
  final DeviceSortColumn sortColumn;
  final SortDirection sortDirection;
  final ValueChanged<DeviceSortColumn> onSort;
  final ValueChanged<Device> onRowTap;

  const DevicesTable({
    super.key,
    required this.devices,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSort,
    required this.onRowTap,
  });

  // Column flex weights — total arbitrary units.
  static const _flex = {
    DeviceSortColumn.hostname: 3,
    DeviceSortColumn.ipAddress: 2,
    DeviceSortColumn.os: 3,
    DeviceSortColumn.user: 2,
    DeviceSortColumn.status: 2,
    DeviceSortColumn.health: 2,
    DeviceSortColumn.lastSeen: 2,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _HeaderRow(
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (devices.isEmpty)
            const _EmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) => _DataRow(
                device: devices[i],
                onTap: () => onRowTap(devices[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final DeviceSortColumn sortColumn;
  final SortDirection sortDirection;
  final ValueChanged<DeviceSortColumn> onSort;

  const _HeaderRow({
    required this.sortColumn,
    required this.sortDirection,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          _HeaderCell(
            label: 'Hostname',
            column: DeviceSortColumn.hostname,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'IP Address',
            column: DeviceSortColumn.ipAddress,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'OS',
            column: DeviceSortColumn.os,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'User',
            column: DeviceSortColumn.user,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Status',
            column: DeviceSortColumn.status,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Health',
            column: DeviceSortColumn.health,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Last Seen',
            column: DeviceSortColumn.lastSeen,
            sortColumn: sortColumn,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          const SizedBox(width: 40), // chevron column
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final DeviceSortColumn column;
  final DeviceSortColumn sortColumn;
  final SortDirection sortDirection;
  final ValueChanged<DeviceSortColumn> onSort;

  const _HeaderCell({
    required this.label,
    required this.column,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final active = column == sortColumn;
    return Expanded(
      flex: DevicesTable._flex[column]!,
      child: InkWell(
        onTap: () => onSort(column),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.seed : AppColors.neutral,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  sortDirection == SortDirection.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 12,
                  color: AppColors.seed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatefulWidget {
  final Device device;
  final VoidCallback onTap;
  const _DataRow({required this.device, required this.onTap});

  @override
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.device;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover
              ? AppColors.seed.withOpacity(0.04)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: DevicesTable._flex[DeviceSortColumn.hostname]!,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: d.isArchived
                            ? AppColors.neutralBg
                            : AppColors.infoBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        d.isArchived
                            ? Icons.archive_outlined
                            : Icons.computer,
                        size: 16,
                        color: d.isArchived
                            ? AppColors.neutral
                            : AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: d.isArchived
                                        ? AppColors.neutral
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (d.isArchived) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ARCHIVED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _secondaryLabel(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.neutral,
                            ),
                          ),
                          if (d.tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _TagChips(tags: d.tags),
                          ],
                          // Active window — surfaced inline so the
                          // operator can scan the fleet and instantly
                          // see who's working on what. Hidden on
                          // archived devices since the agent isn't
                          // reporting any more.
                          if (!d.isArchived) ...[
                            const SizedBox(height: 6),
                            ActiveWindowChip(
                              title: d.activeWindowTitle,
                              processName: d.activeProcessName,
                              seenAt: d.activeWindowSeenAt,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _TextCell(
                column: DeviceSortColumn.ipAddress,
                primary: d.ipAddress,
                secondary: d.macAddress,
              ),
              _TextCell(
                column: DeviceSortColumn.os,
                primary: d.os,
                secondary: d.osVersion,
              ),
              _TextCell(
                column: DeviceSortColumn.user,
                primary: d.assignedUser.isEmpty ? '—' : d.assignedUser,
                secondary: d.location,
              ),
              Expanded(
                flex: DevicesTable._flex[DeviceSortColumn.status]!,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DeviceStatusChip(status: d.status, compact: true),
                ),
              ),
              Expanded(
                flex: DevicesTable._flex[DeviceSortColumn.health]!,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DeviceHealthChip(health: d.health, compact: true),
                ),
              ),
              Expanded(
                flex: DevicesTable._flex[DeviceSortColumn.lastSeen]!,
                child: Text(
                  Formatters.relative(d.lastSeen),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: _hover ? AppColors.seed : AppColors.neutral,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  final DeviceSortColumn column;
  final String primary;
  final String secondary;

  const _TextCell({
    required this.column,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: DevicesTable._flex[column]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (secondary.isNotEmpty)
            Text(
              secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.neutral,
              ),
            ),
        ],
      ),
    );
  }
}

String _secondaryLabel(Device d) {
  // When the operator has set a friendly label we prefer to show the
  // real Windows hostname as the secondary line; otherwise fall back
  // to the manufacturer so the table still feels informative.
  final hasLabel = d.hostnameLabel.trim().isNotEmpty &&
      d.hostnameLabel.trim() != d.hostname;
  if (hasLabel) return d.hostname;
  return d.manufacturer;
}

class _TagChips extends StatelessWidget {
  final List<String> tags;
  const _TagChips({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final t in tags.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              t,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.brandDark,
              ),
            ),
          ),
        if (tags.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              '+${tags.length - 3}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.neutral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: AppColors.neutral),
          const SizedBox(height: 10),
          Text(
            'No devices match your filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try clearing the search or choosing a different status.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}
