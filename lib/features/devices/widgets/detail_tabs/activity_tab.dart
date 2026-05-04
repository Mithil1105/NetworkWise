import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_usage.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/repositories/supabase/supabase_repositories_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/section_card.dart';

/// Phase 22 — Screen-time + per-app history for a single device.
///
/// Pulls aggregated summaries straight from `heartbeat_logs` for
/// "today" and "last 7 days". Each row in heartbeat_logs is a
/// 60-second sample of the active foreground process, so
/// `count(*) × heartbeat_seconds` gives us per-app minutes without any
/// agent-side instrumentation.
class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

enum _Range { today, sevenDays }

class _ActivityTabState extends ConsumerState<ActivityTab> {
  _Range _range = _Range.today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.watch(supabaseActivityRepositoryProvider);
    final heartbeat = ref.watch(settingsProvider).heartbeatSeconds;

    final now = DateTime.now();
    final (from, to, label) = switch (_range) {
      _Range.today => (
          DateTime(now.year, now.month, now.day),
          now,
          'Today',
        ),
      _Range.sevenDays => (
          DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 6)),
          now,
          'Last 7 days',
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Screen-time activity',
            subtitle:
                'Derived from heartbeats — 1 sample every $heartbeat s',
            trailing: _RangeToggle(
              range: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
            child: FutureBuilder<AppUsageSummary>(
              future: repo.summarise(
                deviceId: widget.deviceId,
                from: from,
                to: to,
                heartbeatSeconds: heartbeat,
              ),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const _LoadingPlaceholder();
                }
                if (snap.hasError) {
                  return _ErrorState(
                    message: snap.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }
                final summary = snap.data!;
                if (summary.totalHeartbeats == 0) {
                  return _EmptyState(label: label, theme: theme);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Headline(summary: summary, label: label),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 12),
                    _AppList(summary: summary),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _DisclosureCard(theme: theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.summary, required this.label});

  final AppUsageSummary summary;
  final String label;

  @override
  Widget build(BuildContext context) {
    final activeMinutes = summary.totalActiveSeconds ~/ 60;
    final hours = activeMinutes ~/ 60;
    final minutes = activeMinutes % 60;
    final activeText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final stats = <Widget>[
      _Stat(
        label: '$label — total active',
        value: activeText,
        accent: AppColors.seed,
      ),
      _Stat(
        label: 'Distinct apps',
        value: '${summary.byApp.length}',
        accent: AppColors.info,
      ),
      _Stat(
        label: 'Idle / locked ticks',
        value: '${summary.idleHeartbeats} / ${summary.totalHeartbeats}',
        accent: AppColors.neutral,
      ),
      _Stat(
        label: 'Active proportion',
        value: '${summary.activePercent.toStringAsFixed(0)}%',
        accent: AppColors.success,
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: stats
          .map((s) => SizedBox(width: 180, child: s))
          .toList(growable: false),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.summary});

  final AppUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds =
        summary.byApp.isEmpty ? 1 : summary.byApp.first.seconds;
    final showAll = summary.byApp.length <= 12;
    final visible = showAll ? summary.byApp : summary.byApp.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Top applications',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (!showAll)
                Text(
                  'Showing top 12 of ${summary.byApp.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        for (final bucket in visible)
          _AppRow(
            bucket: bucket,
            maxSeconds: maxSeconds,
          ),
      ],
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.bucket, required this.maxSeconds});

  final AppUsageBucket bucket;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio =
        maxSeconds == 0 ? 0.0 : (bucket.seconds / maxSeconds).clamp(0.0, 1.0);
    final hours = bucket.seconds ~/ 3600;
    final minutes = (bucket.seconds % 3600) ~/ 60;
    final timeText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.desktop_windows_outlined,
                  color: AppColors.info,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bucket.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last seen ${Formatters.relative(bucket.lastSeenAt)} '
                      '— ${bucket.heartbeatCount} samples',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppColors.neutralBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seed),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.range, required this.onChanged});

  final _Range range;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Range>(
      segments: const [
        ButtonSegment(value: _Range.today, label: Text('Today')),
        ButtonSegment(value: _Range.sevenDays, label: Text('7 days')),
      ],
      selected: {range},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off,
              size: 36, color: AppColors.neutral),
          const SizedBox(height: 8),
          Text(
            'No heartbeats in this window ($label)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The endpoint may have been offline, or activity capture has '
            'not been enabled yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not load activity history.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee monitoring — disclosure required',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Captured window titles can include personal data '
                  '(client names, email subjects, document filenames). '
                  'Under the DPDP Act 2023 you must provide written '
                  'notice and obtain employee acknowledgement before '
                  'enabling activity capture on their machine.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
