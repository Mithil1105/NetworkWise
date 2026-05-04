import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../devices/data/mock_devices.dart';
import 'alert_status_badge.dart';
import 'category_chip.dart';

/// Vertical list of alert rows. Each row shows severity, title, device
/// context, timestamp, category and status, plus quick actions.
class AlertList extends StatelessWidget {
  final List<Alert> alerts;
  final ValueChanged<Alert>? onAcknowledge;
  final ValueChanged<Alert>? onResolve;

  const AlertList({
    super.key,
    required this.alerts,
    this.onAcknowledge,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const _EmptyState();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            _AlertRow(
              alert: alerts[i],
              onAcknowledge: onAcknowledge == null
                  ? null
                  : () => onAcknowledge!(alerts[i]),
              onResolve:
                  onResolve == null ? null : () => onResolve!(alerts[i]),
            ),
            if (i != alerts.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onResolve;

  const _AlertRow({
    required this.alert,
    this.onAcknowledge,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = alert.deviceId == null
        ? null
        : MockDevices.byId(alert.deviceId!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SeverityLeading(severity: alert.severity),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SeverityBadge(severity: alert.severity, compact: true),
                    const SizedBox(width: 6),
                    AlertStatusBadge(status: alert.status, compact: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CategoryChip(category: alert.category, compact: true),
                    if (device != null) _DeviceTag(device: device),
                    if (alert.source != null && alert.source!.isNotEmpty)
                      _MetaText(
                        icon: Icons.source_outlined,
                        text: alert.source!,
                      ),
                    _MetaText(
                      icon: Icons.access_time,
                      text: Formatters.relative(alert.timestamp),
                    ),
                    _MetaText(
                      icon: Icons.tag,
                      text: alert.id,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _Actions(
            status: alert.status,
            onAcknowledge: onAcknowledge,
            onResolve: onResolve,
          ),
        ],
      ),
    );
  }
}

class _SeverityLeading extends StatelessWidget {
  final AlertSeverity severity;
  const _SeverityLeading({required this.severity});

  ({Color bg, Color fg, IconData icon}) get _style {
    switch (severity) {
      case AlertSeverity.info:
        return (
          bg: AppColors.infoBg,
          fg: AppColors.info,
          icon: Icons.info_outline,
        );
      case AlertSeverity.low:
        return (
          bg: AppColors.successBg,
          fg: AppColors.success,
          icon: Icons.flag_outlined,
        );
      case AlertSeverity.medium:
        return (
          bg: AppColors.warningBg,
          fg: AppColors.warning,
          icon: Icons.error_outline,
        );
      case AlertSeverity.high:
        return (
          bg: AppColors.dangerBg,
          fg: AppColors.danger,
          icon: Icons.local_fire_department_outlined,
        );
      case AlertSeverity.critical:
        return (
          bg: AppColors.danger,
          fg: Colors.white,
          icon: Icons.whatshot,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(s.icon, size: 18, color: s.fg),
    );
  }
}

class _DeviceTag extends StatelessWidget {
  final Device device;
  const _DeviceTag({required this.device});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.computer, size: 12, color: AppColors.info),
        const SizedBox(width: 4),
        Text(
          device.displayName,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '— ${device.location}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.neutral,
          ),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.neutral),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.neutral,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final AlertStatus status;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onResolve;

  const _Actions({
    required this.status,
    this.onAcknowledge,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    // Resolved alerts need no further action.
    if (status == AlertStatus.resolved) {
      return const SizedBox(width: 120);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == AlertStatus.open)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              onPressed: onAcknowledge,
              icon: const Icon(Icons.visibility_outlined, size: 14),
              label: const Text('Acknowledge'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (status == AlertStatus.open) const SizedBox(height: 4),
        SizedBox(
          height: 30,
          child: TextButton.icon(
            onPressed: onResolve,
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('Resolve'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 28,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No alerts match these filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try clearing a filter or widening the severity selection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
