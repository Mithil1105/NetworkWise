import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Reusable horizontal "label : value" row. Copy-friendly by default.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final IconData? icon;
  final bool dense;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.neutral),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neutral,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Wrap-friendly grid of InfoRows rendered in two responsive columns.
class InfoGrid extends StatelessWidget {
  final List<InfoRow> rows;
  final double columnSpacing;

  const InfoGrid({
    super.key,
    required this.rows,
    this.columnSpacing = 24,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final singleColumn = c.maxWidth < 720;
        if (singleColumn) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
        }
        final half = (rows.length / 2).ceil();
        final left = rows.sublist(0, half);
        final right = rows.sublist(half);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            SizedBox(width: columnSpacing),
            Expanded(child: Column(children: right)),
          ],
        );
      },
    );
  }
}
