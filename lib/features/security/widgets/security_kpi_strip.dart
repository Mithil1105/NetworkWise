import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/mock_fleet_security.dart';

class SecurityKpiStrip extends StatelessWidget {
  final FleetSecuritySummary summary;

  const SecurityKpiStrip({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        var perRow = (c.maxWidth / 240).floor();
        if (perRow > 4) perRow = 4;
        if (perRow < 1) perRow = 1;
        final w = (c.maxWidth - gap * (perRow - 1)) / perRow;

        Widget tile(Widget w) => SizedBox(width: w is SizedBox ? 0 : 0);

        final cards = <Widget>[
          _KpiTile(
            label: 'Compliant',
            value: summary.compliant.toString(),
            subtitle: 'of ${summary.total} devices',
            color: AppColors.success,
            icon: Icons.verified,
          ),
          _KpiTile(
            label: 'At Risk',
            value: summary.atRisk.toString(),
            subtitle: 'needing attention',
            color: AppColors.warning,
            icon: Icons.warning_amber_rounded,
          ),
          _KpiTile(
            label: 'Critical',
            value: summary.critical.toString(),
            subtitle: 'immediate action',
            color: AppColors.danger,
            icon: Icons.error_outline,
          ),
          _ScoreTile(score: summary.score),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: w, child: card),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
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
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.neutral,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final double score;
  const _ScoreTile({required this.score});

  Color get _color {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 90) return 'Strong';
    if (score >= 75) return 'Moderate';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
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
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shield, color: _color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  score.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 2),
                const Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.neutral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Security Score',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.neutral,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'weighted across controls',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
