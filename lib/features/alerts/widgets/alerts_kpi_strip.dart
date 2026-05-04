import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';

/// Four summary tiles at the top of the Alerts screen.
/// Counts are derived from the fleet alert list.
class AlertsKpiStrip extends StatelessWidget {
  final List<Alert> alerts;

  const AlertsKpiStrip({super.key, required this.alerts});

  int get _openCount =>
      alerts.where((a) => a.status == AlertStatus.open).length;

  int get _criticalOpen => alerts
      .where(
        (a) =>
            a.status == AlertStatus.open &&
            a.severity == AlertSeverity.critical,
      )
      .length;

  int get _highOpen => alerts
      .where(
        (a) =>
            a.status == AlertStatus.open && a.severity == AlertSeverity.high,
      )
      .length;

  int get _resolvedToday {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return alerts
        .where(
          (a) =>
              a.status == AlertStatus.resolved &&
              a.timestamp.isAfter(start),
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const minWidth = 220.0;
        final cols = (c.maxWidth / minWidth).floor().clamp(1, 4);
        final spacing = 16.0;
        final tileW =
            (c.maxWidth - spacing * (cols - 1)) / cols;

        final tiles = <Widget>[
          _Tile(
            width: tileW,
            label: 'Open alerts',
            value: _openCount.toString(),
            icon: Icons.error_outline,
            tone: AppColors.danger,
            toneBg: AppColors.dangerBg,
          ),
          _Tile(
            width: tileW,
            label: 'Critical — open',
            value: _criticalOpen.toString(),
            icon: Icons.warning_amber_outlined,
            tone: Colors.white,
            toneBg: AppColors.danger,
            critical: true,
          ),
          _Tile(
            width: tileW,
            label: 'High — open',
            value: _highOpen.toString(),
            icon: Icons.local_fire_department_outlined,
            tone: AppColors.warning,
            toneBg: AppColors.warningBg,
          ),
          _Tile(
            width: tileW,
            label: 'Resolved today',
            value: _resolvedToday.toString(),
            icon: Icons.check_circle_outline,
            tone: AppColors.success,
            toneBg: AppColors.successBg,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles,
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final Color toneBg;
  final bool critical;

  const _Tile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.toneBg,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: toneBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: tone),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.neutral,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: critical
                            ? AppColors.danger
                            : theme.colorScheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
