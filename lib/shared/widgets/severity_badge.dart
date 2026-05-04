import 'package:flutter/material.dart';

import '../../core/models/alert.dart';
import '../../core/theme/app_colors.dart';

/// Coloured pill communicating an alert's severity. Reused by Dashboard
/// (recent alerts) and the full Alerts screen.
class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;
  final bool compact;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.compact = false,
  });

  ({Color fg, Color bg, String label}) get _style {
    switch (severity) {
      case AlertSeverity.info:
        return (fg: AppColors.info, bg: AppColors.infoBg, label: 'INFO');
      case AlertSeverity.low:
        return (fg: AppColors.success, bg: AppColors.successBg, label: 'LOW');
      case AlertSeverity.medium:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          label: 'MEDIUM'
        );
      case AlertSeverity.high:
        return (fg: AppColors.danger, bg: AppColors.dangerBg, label: 'HIGH');
      case AlertSeverity.critical:
        return (
          fg: Colors.white,
          bg: AppColors.danger,
          label: 'CRITICAL'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          color: s.fg,
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
