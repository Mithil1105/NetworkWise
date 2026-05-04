import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Segmented control for Light / Dark / System.
class ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            active: value == ThemeMode.light,
            icon: Icons.light_mode_outlined,
            label: 'Light',
            onTap: () => onChanged(ThemeMode.light),
          ),
          _Segment(
            active: value == ThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            onTap: () => onChanged(ThemeMode.dark),
          ),
          _Segment(
            active: value == ThemeMode.system,
            icon: Icons.desktop_windows_outlined,
            label: 'System',
            onTap: () => onChanged(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Segment({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.seed : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.white : AppColors.neutral,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
