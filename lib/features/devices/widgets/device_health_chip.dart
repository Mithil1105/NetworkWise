import 'package:flutter/material.dart';

import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';

/// Compact pill — Healthy / Warning / Critical / Unknown — with an icon.
class DeviceHealthChip extends StatelessWidget {
  final HealthStatus health;
  final bool compact;

  const DeviceHealthChip({
    super.key,
    required this.health,
    this.compact = false,
  });

  ({Color fg, Color bg, IconData icon, String label}) get _style {
    switch (health) {
      case HealthStatus.healthy:
        return (
          fg: AppColors.success,
          bg: AppColors.successBg,
          icon: Icons.check_circle,
          label: 'Healthy',
        );
      case HealthStatus.warning:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          icon: Icons.warning_amber_rounded,
          label: 'Warning',
        );
      case HealthStatus.critical:
        return (
          fg: AppColors.danger,
          bg: AppColors.dangerBg,
          icon: Icons.error_outline,
          label: 'Critical',
        );
      case HealthStatus.unknown:
        return (
          fg: AppColors.neutral,
          bg: AppColors.neutralBg,
          icon: Icons.help_outline,
          label: 'Unknown',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 13, color: s.fg),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: s.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
