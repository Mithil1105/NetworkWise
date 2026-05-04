import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A single preference row — left side has label + help text, right side
/// shows the actual control (dropdown, stepper, switch, etc.).
/// The row reflows to stacked layout below [breakpoint] pixels.
class SettingRow extends StatelessWidget {
  final String label;
  final String? help;
  final Widget control;
  final double breakpoint;

  const SettingRow({
    super.key,
    required this.label,
    required this.control,
    this.help,
    this.breakpoint = 640,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < breakpoint;

        final labelBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (help != null) ...[
              const SizedBox(height: 4),
              Text(
                help!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.neutral,
                  height: 1.4,
                ),
              ),
            ],
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    labelBlock,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: control),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: labelBlock),
                    const SizedBox(width: 20),
                    control,
                  ],
                ),
        );
      },
    );
  }
}
