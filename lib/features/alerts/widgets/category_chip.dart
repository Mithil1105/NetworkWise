import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';

/// Neutral pill surfacing an alert's category with a matching icon.
class CategoryChip extends StatelessWidget {
  final AlertCategory category;
  final bool compact;

  const CategoryChip({
    super.key,
    required this.category,
    this.compact = false,
  });

  ({IconData icon, String label}) get _meta => iconAndLabelFor(category);

  static ({IconData icon, String label}) iconAndLabelFor(
    AlertCategory category,
  ) {
    switch (category) {
      case AlertCategory.system:
        return (icon: Icons.memory, label: 'System');
      case AlertCategory.network:
        return (icon: Icons.lan_outlined, label: 'Network');
      case AlertCategory.security:
        return (icon: Icons.shield_outlined, label: 'Security');
      case AlertCategory.performance:
        return (icon: Icons.speed_outlined, label: 'Performance');
      case AlertCategory.other:
        return (icon: Icons.category_outlined, label: 'Other');
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutralBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m.icon, size: compact ? 11.0 : 12.5, color: AppColors.neutral),
          const SizedBox(width: 5),
          Text(
            m.label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral,
            ),
          ),
        ],
      ),
    );
  }
}
