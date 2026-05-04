import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/system_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../devices/widgets/active_window_chip.dart';

class SystemSummaryPanel extends StatelessWidget {
  final SystemStatus status;

  const SystemSummaryPanel({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'System Summary',
      subtitle: status.hostname,
      trailing: _LivePill(timestamp: status.timestamp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricBar(
            label: 'CPU',
            sublabel: status.cpuName,
            percent: status.cpuUsagePercent,
            warningAt: AppConstants.cpuWarningPercent,
          ),
          const SizedBox(height: 14),
          _MetricBar(
            label: 'Memory',
            sublabel:
                '${status.usedRamGb.toStringAsFixed(1)} / ${status.totalRamGb.toStringAsFixed(0)} GB',
            percent: status.memoryUsagePercent,
            warningAt: AppConstants.memoryWarningPercent,
          ),
          const SizedBox(height: 14),
          // Per-disk bars when the probe was able to enumerate volumes
          // individually; falls back to the single aggregate bar on
          // older endpoints / failed probes so the dashboard never goes
          // empty.
          if (status.disks.isEmpty)
            _MetricBar(
              label: 'Disk',
              sublabel:
                  '${status.diskUsedGb.toStringAsFixed(0)} / ${status.diskTotalGb.toStringAsFixed(0)} GB',
              percent: status.diskUsagePercent,
              warningAt: AppConstants.defaultStorageThresholdPercent,
            )
          else
            for (var i = 0; i < status.disks.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _MetricBar(
                label: status.disks[i].displayName,
                sublabel:
                    '${status.disks[i].usedGb.toStringAsFixed(0)} / ${status.disks[i].totalGb.toStringAsFixed(0)} GB'
                    '${status.disks[i].fileSystem.isNotEmpty ? ' • ${status.disks[i].fileSystem}' : ''}',
                percent: status.disks[i].usagePercent,
                warningAt: AppConstants.defaultStorageThresholdPercent,
              ),
            ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          // Currently working on — the foreground window the probe just
          // captured. Shows "Idle / locked" when the desktop is locked.
          Row(
            children: [
              const Text(
                'Working on',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ActiveWindowChip(
                  title: status.activeWindowTitle,
                  processName: status.activeProcessName,
                  seenAt: status.timestamp,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoTile(
                label: 'OS',
                value: status.os,
              ),
              _InfoTile(
                label: 'Build',
                value: status.osBuild,
              ),
              _InfoTile(
                label: 'Uptime',
                value: Formatters.uptime(status.uptimeSeconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final String sublabel;
  final double percent;
  final double warningAt;

  const _MetricBar({
    required this.label,
    required this.sublabel,
    required this.percent,
    required this.warningAt,
  });

  Color get _color {
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

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.neutral),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final DateTime timestamp;
  const _LivePill({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Live — ${Formatters.relative(timestamp)}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
