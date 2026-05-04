import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_card.dart';
import '../data/mock_fleet_security.dart';
import 'security_stat_bar.dart';

class AntivirusCard extends StatelessWidget {
  final FleetSecuritySummary summary;
  const AntivirusCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final allEnabled = summary.avEnabled == summary.total;
    final allUpToDate = summary.avUpToDate == summary.total;
    final headlineColor = allEnabled && allUpToDate
        ? AppColors.success
        : (summary.avEnabled < summary.total * 0.8
            ? AppColors.danger
            : AppColors.warning);

    return SectionCard(
      title: 'Antivirus',
      subtitle: 'Windows Defender — fleet coverage',
      trailing: _HeadlineBadge(
        color: headlineColor,
        icon: Icons.shield_moon,
        label: allEnabled && allUpToDate ? 'Healthy' : 'Gaps detected',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecurityStatBar(
            label: 'Engine enabled',
            count: summary.avEnabled,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'Signatures up-to-date',
            count: summary.avUpToDate,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'Real-time protection',
            count: summary.avRealTime,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'Scanned in last 24h',
            count: summary.avScannedRecently,
            total: summary.total,
            warningAt: 75,
            dangerAt: 50,
          ),
        ],
      ),
    );
  }
}

class _HeadlineBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _HeadlineBadge({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
