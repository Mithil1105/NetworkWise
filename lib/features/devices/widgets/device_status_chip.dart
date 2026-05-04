import 'package:flutter/material.dart';

import '../../../core/models/device.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_dot.dart';

/// Compact pill — "Online" / "Offline" / "Warning" — with a coloured dot.
class DeviceStatusChip extends StatelessWidget {
  final DeviceStatus status;
  final bool compact;

  const DeviceStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  ({Color fg, Color bg, String label}) get _style {
    switch (status) {
      case DeviceStatus.online:
        return (
          fg: AppColors.success,
          bg: AppColors.successBg,
          label: 'Online',
        );
      case DeviceStatus.offline:
        return (
          fg: AppColors.neutral,
          bg: AppColors.neutralBg,
          label: 'Offline',
        );
      case DeviceStatus.warning:
        return (
          fg: AppColors.warning,
          bg: AppColors.warningBg,
          label: 'Warning',
        );
      case DeviceStatus.unknown:
        return (
          fg: AppColors.neutral,
          bg: AppColors.neutralBg,
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
          StatusDot.forDevice(status),
          const SizedBox(width: 6),
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
