import 'package:flutter/material.dart';

import '../../../../core/models/alert.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../shared/widgets/severity_badge.dart';

class AlertsHistoryTab extends StatelessWidget {
  final List<Alert> alerts;

  const AlertsHistoryTab({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    final counts = _counts(alerts);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Summary(
                label: 'Total',
                value: alerts.length.toString(),
                color: AppColors.seed,
              ),
              const SizedBox(width: 12),
              _Summary(
                label: 'Open',
                value: counts[AlertStatus.open].toString(),
                color: AppColors.danger,
              ),
              const SizedBox(width: 12),
              _Summary(
                label: 'Acknowledged',
                value: counts[AlertStatus.acknowledged].toString(),
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _Summary(
                label: 'Resolved',
                value: counts[AlertStatus.resolved].toString(),
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'History',
            subtitle: 'Last ${alerts.length} alerts on this device',
            child: alerts.isEmpty
                ? const _Empty()
                : Column(
                    children: [
                      for (var i = 0; i < alerts.length; i++) ...[
                        _AlertTile(alert: alerts[i]),
                        if (i != alerts.length - 1)
                          const Divider(height: 1, color: AppColors.divider),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Map<AlertStatus, int> _counts(List<Alert> a) {
    final m = {
      AlertStatus.open: 0,
      AlertStatus.acknowledged: 0,
      AlertStatus.resolved: 0,
    };
    for (final x in a) {
      m[x.status] = (m[x.status] ?? 0) + 1;
    }
    return m;
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Summary({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Alert alert;
  const _AlertTile({required this.alert});

  ({Color fg, Color bg, String label}) get _statusStyle {
    switch (alert.status) {
      case AlertStatus.open:
        return (fg: AppColors.danger, bg: AppColors.dangerBg, label: 'Open');
      case AlertStatus.acknowledged:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          label: 'Acknowledged'
        );
      case AlertStatus.resolved:
        return (
          fg: AppColors.success,
          bg: AppColors.successBg,
          label: 'Resolved'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _statusStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_outlined,
                size: 16, color: AppColors.neutral),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SeverityBadge(severity: alert.severity, compact: true),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: s.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: s.fg,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.source ?? 'System'}  •  ${alert.category.name}  •  ${Formatters.dateTime(alert.timestamp)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: AppColors.neutral),
          const SizedBox(height: 8),
          Text(
            'No alerts for this device',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
