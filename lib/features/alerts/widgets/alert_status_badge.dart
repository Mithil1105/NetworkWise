import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';

/// Compact pill describing an alert's workflow status.
class AlertStatusBadge extends StatelessWidget {
  final AlertStatus status;
  final bool compact;

  const AlertStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  ({Color fg, Color bg, IconData icon, String label}) get _style {
    switch (status) {
      case AlertStatus.open:
        return (
          fg: AppColors.danger,
          bg: AppColors.dangerBg,
          icon: Icons.error_outline,
          label: 'Open',
        );
      case AlertStatus.acknowledged:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          icon: Icons.visibility_outlined,
          label: 'Acknowledged',
        );
      case AlertStatus.resolved:
        return (
          fg: AppColors.success,
          bg: AppColors.successBg,
          icon: Icons.check_circle_outline,
          label: 'Resolved',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 11.0 : 13.0, color: s.fg),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: s.fg,
            ),
          ),
        ],
      ),
    );
  }
}
