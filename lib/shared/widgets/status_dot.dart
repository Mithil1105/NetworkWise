import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import '../../core/theme/app_colors.dart';

/// Small coloured dot used in rows / badges to convey status at a glance.
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.size = 8,
  });

  factory StatusDot.forDevice(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.online:
        return const StatusDot(color: AppColors.success);
      case DeviceStatus.offline:
        return const StatusDot(color: AppColors.neutral);
      case DeviceStatus.warning:
        return const StatusDot(color: AppColors.warning);
      case DeviceStatus.unknown:
        return const StatusDot(color: AppColors.neutral);
    }
  }

  factory StatusDot.forHealth(HealthStatus h) {
    switch (h) {
      case HealthStatus.healthy:
        return const StatusDot(color: AppColors.success);
      case HealthStatus.warning:
        return const StatusDot(color: AppColors.warning);
      case HealthStatus.critical:
        return const StatusDot(color: AppColors.danger);
      case HealthStatus.unknown:
        return const StatusDot(color: AppColors.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
