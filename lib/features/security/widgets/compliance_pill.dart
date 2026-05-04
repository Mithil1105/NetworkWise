import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/mock_fleet_security.dart';

/// Green/yellow/red pill for fleet-level compliance status.
class CompliancePill extends StatelessWidget {
  final ComplianceLevel level;
  final bool compact;

  const CompliancePill({
    super.key,
    required this.level,
    this.compact = false,
  });

  ({Color fg, Color bg, IconData icon, String label}) get _style {
    switch (level) {
      case ComplianceLevel.compliant:
        return (
          fg: AppColors.success,
          bg: AppColors.successBg,
          icon: Icons.verified,
          label: 'Compliant',
        );
      case ComplianceLevel.atRisk:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          icon: Icons.warning_amber_rounded,
          label: 'At risk',
        );
      case ComplianceLevel.critical:
        return (
          fg: AppColors.danger,
          bg: AppColors.dangerBg,
          icon: Icons.error_outline,
          label: 'Critical',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 14, color: s.fg),
          const SizedBox(width: 6),
          Text(
            s.label,
            style: TextStyle(
              fontSize: compact ? 11 : 11.5,
              color: s.fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
