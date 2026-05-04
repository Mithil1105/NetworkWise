import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A single "Label — 12/14 — 86%" row with a filled progress bar
/// that turns green / amber / red based on the ratio.
class SecurityStatBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final double warningAt; // below this percent the bar turns amber
  final double dangerAt; // below this percent the bar turns red

  const SecurityStatBar({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    this.warningAt = 90,
    this.dangerAt = 70,
  });

  double get _percent => total == 0 ? 0 : (count / total) * 100.0;

  Color get _color {
    final p = _percent;
    if (p < dangerAt) return AppColors.danger;
    if (p < warningAt) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$count / $total',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                alignment: Alignment.centerRight,
                child: Text(
                  '${_percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_percent / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.neutralBg,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ],
      ),
    );
  }
}
