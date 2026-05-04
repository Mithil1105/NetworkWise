import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Trend direction shown next to the value.
enum KpiTrend { up, down, flat }

/// A single KPI tile — icon, label, value, optional trend & delta.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String? delta;
  final KpiTrend trend;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    this.delta,
    this.trend = KpiTrend.flat,
    this.onTap,
  });

  Color get _trendColor {
    switch (trend) {
      case KpiTrend.up:
        return AppColors.success;
      case KpiTrend.down:
        return AppColors.danger;
      case KpiTrend.flat:
        return AppColors.neutral;
    }
  }

  IconData get _trendIcon {
    switch (trend) {
      case KpiTrend.up:
        return Icons.arrow_upward;
      case KpiTrend.down:
        return Icons.arrow_downward;
      case KpiTrend.flat:
        return Icons.remove;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  if (delta != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_trendIcon, size: 14, color: _trendColor),
                        const SizedBox(width: 2),
                        Text(
                          delta!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _trendColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
