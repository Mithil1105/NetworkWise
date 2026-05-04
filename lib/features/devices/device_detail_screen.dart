import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin/device_admin_provider.dart';
import '../../core/config/env.dart';
import '../../core/models/device.dart';
import '../../core/providers/devices_provider.dart';
import '../../core/services/data_service_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'data/mock_device_detail.dart';
import 'widgets/active_window_chip.dart';
import 'widgets/detail_tabs/activity_tab.dart';
import 'widgets/detail_tabs/alerts_history_tab.dart';
import 'widgets/detail_tabs/general_info_tab.dart';
import 'widgets/detail_tabs/network_info_tab.dart';
import 'widgets/detail_tabs/security_info_tab.dart';
import 'widgets/detail_tabs/system_info_tab.dart';
import 'widgets/device_health_chip.dart';
import 'widgets/device_status_chip.dart';
import 'widgets/edit_device_dialog.dart';

/// Device detail with General / Network / Security / System / Alerts tabs.
class DeviceDetailScreen extends ConsumerStatefulWidget {
  final Device device;
  final VoidCallback onBack;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.onBack,
  });

  @override
  ConsumerState<DeviceDetailScreen> createState() =>
      _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MockDeviceDetail _detail;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _detail = ref.read(dataServiceProvider).getDeviceDetail(widget.device.id);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final updated = await EditDeviceDialog.show(context, widget.device);
    if (!mounted || updated == null) return;
    // Devices provider auto-refreshes on the next realtime tick; we
    // still nudge the list so the back-navigation shows the new label.
    ref.invalidate(devicesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device updated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context,
      {required bool archive}) async {
    final label = widget.device.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(archive ? 'Archive $label?' : 'Restore $label?'),
        content: Text(
          archive
              ? 'The device will be hidden from the default Devices list. '
                  'It stops counting towards fleet KPIs but its heartbeat '
                  'history and alerts are preserved for audit.\n\nThe '
                  'endpoint itself keeps running — it will simply not be '
                  'surfaced in the console until you restore it.'
              : 'The device will re-appear in the Devices list and start '
                  'counting towards fleet KPIs again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: archive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(archive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(deviceAdminControllerProvider).updateDevice(
            deviceId: widget.device.id,
            archived: archive,
          );
      if (!mounted) return;
      ref.invalidate(devicesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive ? 'Device archived' : 'Device restored'),
          duration: const Duration(seconds: 2),
        ),
      );
      // If we just archived, bounce back to the list so the operator
      // sees the device removed from the default view.
      if (archive) widget.onBack();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archive failed — $err'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            device: widget.device,
            onBack: widget.onBack,
            onEdit: Env.isAdminRole ? () => _openEditDialog(context) : null,
            onArchive: Env.isAdminRole
                ? () => _confirmArchive(context, archive: !widget.device.isArchived)
                : null,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.seed,
              unselectedLabelColor: AppColors.neutral,
              indicatorColor: AppColors.seed,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Network'),
                Tab(text: 'Security'),
                Tab(text: 'System'),
                Tab(text: 'Activity'),
                Tab(text: 'Alerts'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                GeneralInfoTab(device: widget.device, detail: _detail),
                NetworkInfoTab(adapters: _detail.adapters),
                SecurityInfoTab(
                  security: _detail.security,
                  deviceId: widget.device.id,
                ),
                SystemInfoTab(system: _detail.system),
                ActivityTab(deviceId: widget.device.id),
                AlertsHistoryTab(alerts: _detail.alertHistory),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Device device;
  final VoidCallback onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  const _Header({
    required this.device,
    required this.onBack,
    this.onEdit,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final archived = device.isArchived;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to devices',
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: archived ? AppColors.neutralBg : AppColors.infoBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            archived ? Icons.archive_outlined : Icons.computer,
            color: archived ? AppColors.neutral : AppColors.info,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      device.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (device.hostnameLabel.trim().isNotEmpty &&
                      device.hostnameLabel.trim() != device.hostname) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutralBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        device.hostname,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral,
                        ),
                      ),
                    ),
                  ],
                  if (archived) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ARCHIVED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${device.manufacturer} — ${device.model}  •  '
                '${device.ipAddress}  •  Last seen ${Formatters.relative(device.lastSeen)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.neutral,
                ),
              ),
              // "Currently working on" — the foreground window the
              // endpoint reported on its latest heartbeat tick. Hidden
              // on archived devices since the agent isn't reporting.
              if (!archived) ...[
                const SizedBox(height: 8),
                ActiveWindowChip(
                  title: device.activeWindowTitle,
                  processName: device.activeProcessName,
                  seenAt: device.activeWindowSeenAt,
                ),
              ],
            ],
          ),
        ),
        DeviceStatusChip(status: device.status),
        const SizedBox(width: 8),
        DeviceHealthChip(health: device.health),
        const SizedBox(width: 16),
        if (onEdit != null) ...[
          _ActionButton(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: onEdit!,
          ),
          const SizedBox(width: 8),
        ],
        if (onArchive != null)
          _ActionButton(
            icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: archived ? 'Restore' : 'Archive',
            onTap: onArchive!,
            tone: archived ? _Tone.neutral : _Tone.danger,
          ),
      ],
    );
  }
}

enum _Tone { neutral, danger }

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _Tone tone;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _Tone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = tone == _Tone.danger;
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isDanger ? AppColors.danger : theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: isDanger ? AppColors.danger : theme.dividerColor,
        ),
      ),
    );
  }
}
