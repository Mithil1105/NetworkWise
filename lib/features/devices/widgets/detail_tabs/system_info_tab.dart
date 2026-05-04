import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/system_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/info_row.dart';
import '../../../../shared/widgets/section_card.dart';

class SystemInfoTab extends StatelessWidget {
  final SystemStatus system;

  const SystemInfoTab({super.key, required this.system});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Operating System',
            subtitle: 'Build, architecture and uptime',
            child: InfoGrid(
              rows: [
                InfoRow(label: 'OS', value: system.os),
                InfoRow(label: 'Build', value: system.osBuild),
                InfoRow(label: 'Architecture', value: system.architecture),
                InfoRow(
                  label: 'Uptime',
                  value: Formatters.uptime(system.uptimeSeconds),
                ),
                InfoRow(
                  label: 'Snapshot taken',
                  value: Formatters.dateTime(system.timestamp),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Live Utilisation',
            subtitle: 'CPU, memory, disk and battery',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UsageBar(
                  label: 'CPU',
                  sublabel: '${system.cpuName} (${system.cpuCores} cores)',
                  percent: system.cpuUsagePercent,
                  warningAt: AppConstants.cpuWarningPercent,
                ),
                const SizedBox(height: 14),
                _UsageBar(
                  label: 'Memory',
                  sublabel:
                      '${system.usedRamGb.toStringAsFixed(1)} GB used of ${system.totalRamGb.toStringAsFixed(0)} GB',
                  percent: system.memoryUsagePercent,
                  warningAt: AppConstants.memoryWarningPercent,
                ),
                const SizedBox(height: 14),
                _UsageBar(
                  label: 'Disk (C:)',
                  sublabel:
                      '${system.diskUsedGb.toStringAsFixed(0)} GB used of ${system.diskTotalGb.toStringAsFixed(0)} GB',
                  percent: system.diskUsagePercent,
                  warningAt: AppConstants.defaultStorageThresholdPercent,
                ),
                if (system.batteryPercent != null) ...[
                  const SizedBox(height: 14),
                  _UsageBar(
                    label: 'Battery',
                    sublabel: (system.isCharging ?? false)
                        ? 'Charging — AC connected'
                        : 'On battery',
                    percent: system.batteryPercent!.toDouble(),
                    warningAt: 40,
                    invertThreshold: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  final String label;
  final String sublabel;
  final double percent;
  final double warningAt;

  /// When true, LOW values are warning (e.g. battery below threshold).
  final bool invertThreshold;

  const _UsageBar({
    required this.label,
    required this.sublabel,
    required this.percent,
    required this.warningAt,
    this.invertThreshold = false,
  });

  Color get _color {
    if (invertThreshold) {
      if (percent <= 15) return AppColors.danger;
      if (percent <= warningAt) return AppColors.warning;
      return AppColors.success;
    }
    if (percent >= 95) return AppColors.danger;
    if (percent >= warningAt) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Formatters.percent(percent, fractionDigits: 1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0, 1),
            minHeight: 6,
            backgroundColor: AppColors.neutralBg,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}
