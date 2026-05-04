import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/severity_badge.dart';

class RecentAlertsPanel extends StatelessWidget {
  final List<Alert> alerts;
  final VoidCallback? onViewAll;

  const RecentAlertsPanel({
    super.key,
    required this.alerts,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent Alerts',
      subtitle: '${alerts.length} triggered in the last 24 hours',
      trailing: TextButton(
        onPressed: onViewAll,
        child: const Text('View all'),
      ),
      child: alerts.isEmpty
          ? const _EmptyAlerts()
          : Column(
              children: [
                for (var i = 0; i < alerts.length; i++) ...[
                  _AlertRow(alert: alerts[i]),
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
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded,
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.source ?? 'System'} — ${Formatters.relative(alert.timestamp)}',
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

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 36),
          const SizedBox(height: 8),
          Text(
            'All clear',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'No alerts in the last 24 hours.',
            style: TextStyle(fontSize: 12, color: AppColors.neutral),
          ),
        ],
      ),
    );
  }
}
