import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/section_card.dart';
import '../data/mock_fleet_security.dart';
import 'security_stat_bar.dart';

class FirewallCard extends StatelessWidget {
  final FleetSecuritySummary summary;
  const FirewallCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final allThree = summary.fwAllThree == summary.total;
    final color = allThree
        ? AppColors.success
        : summary.fwAllThree < summary.total * 0.8
            ? AppColors.danger
            : AppColors.warning;

    return SectionCard(
      title: 'Firewall',
      subtitle: 'Profile-level enforcement across the fleet',
      trailing: _HeadlineBadge(
        color: color,
        icon: Icons.lan_outlined,
        label: allThree ? 'All profiles on' : 'Some profiles off',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecurityStatBar(
            label: 'Domain profile enabled',
            count: summary.fwDomain,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'Private profile enabled',
            count: summary.fwPrivate,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'Public profile enabled',
            count: summary.fwPublic,
            total: summary.total,
          ),
          SecurityStatBar(
            label: 'All three profiles on',
            count: summary.fwAllThree,
            total: summary.total,
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
