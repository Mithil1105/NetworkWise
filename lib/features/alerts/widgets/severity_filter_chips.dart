import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';

/// Horizontal chip bar letting the user toggle which severities are
/// visible. An empty set is interpreted as "show all" by the parent.
class SeverityFilterChips extends StatelessWidget {
  final Set<AlertSeverity> selected;
  final ValueChanged<AlertSeverity> onToggle;

  const SeverityFilterChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in AlertSeverity.values)
          _SeverityChip(
            severity: s,
            active: selected.contains(s),
            onTap: () => onToggle(s),
          ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final AlertSeverity severity;
  final bool active;
  final VoidCallback onTap;

  const _SeverityChip({
    required this.severity,
    required this.active,
    required this.onTap,
  });

  ({Color fg, Color bg, String label}) get _style {
    switch (severity) {
      case AlertSeverity.info:
        return (fg: AppColors.info, bg: AppColors.infoBg, label: 'Info');
      case AlertSeverity.low:
        return (fg: AppColors.success, bg: AppColors.successBg, label: 'Low');
      case AlertSeverity.medium:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          label: 'Medium',
        );
      case AlertSeverity.high:
        return (fg: AppColors.danger, bg: AppColors.dangerBg, label: 'High');
      case AlertSeverity.critical:
        return (fg: Colors.white, bg: AppColors.danger, label: 'Critical');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final isCritical = severity == AlertSeverity.critical;

    final bg = active ? s.bg : Colors.white;
    final border = active
        ? s.fg.withOpacity(isCritical ? 1.0 : 0.4)
        : AppColors.divider;
    final fg = active ? s.fg : AppColors.neutral;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          s.label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
