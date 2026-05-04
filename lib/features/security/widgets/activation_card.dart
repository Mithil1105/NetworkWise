import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_card.dart';
import '../data/mock_fleet_security.dart';
import 'security_stat_bar.dart';

class ActivationCard extends StatelessWidget {
  final FleetSecuritySummary summary;
  const ActivationCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final allActivated = summary.activated == summary.total;
    final color = allActivated
        ? AppColors.success
        : summary.activated < summary.total * 0.85
            ? AppColors.danger
            : AppColors.warning;

    return SectionCard(
      title: 'Activation & Encryption',
      subtitle: 'Windows licensing, BitLocker and updates',
      trailing: _HeadlineBadge(
        color: color,
        icon: Icons.verified_user_outlined,
        label: allActivated ? 'Licensed' : 'Unlicensed devices',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecurityStatBar(
            label: 'Windows activated',
            count: summary.activated,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'BitLocker enabled',
            count: summary.bitLocker,
            total: summary.total,
            warningAt: 80,
            dangerAt: 50,
          ),
          SecurityStatBar(
            label: 'Updates checked this week',
            count: summary.updatedRecently,
            total: summary.total,
            warningAt: 85,
            dangerAt: 60,
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
