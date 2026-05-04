import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/alert.dart';
import '../../core/models/device.dart';
import '../../core/models/system_status.dart';
import '../../core/providers/alerts_provider.dart';
import '../../core/providers/devices_provider.dart';
import '../../core/services/system_probe/system_probe_provider.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/activity_chart.dart';
import 'widgets/enrollment_cta_banner.dart';
import 'widgets/kpi_card.dart';
import 'widgets/kpi_strip.dart';
import 'widgets/recent_alerts_panel.dart';
import 'widgets/system_summary_panel.dart';

/// Dashboard — KPI strip, activity chart, recent alerts + system summary.
///
/// Every live figure (total / online device counts, active alerts, recent
/// alerts list) is now derived from the Riverpod providers that sit on
/// top of [IDataService]. The historical activity series stays inline —
/// it's a 14-period retrospective that will move to a dedicated
/// telemetry provider in a future phase.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  // --- Inline historical chart series (retrospective preview only) ---
  static const _labels = <String>[
    '8', '9', '10', '11', '12', '13', '14',
    '15', '16', '17', '18', '19', '20', '21',
  ];
  static const _online = <double>[
    112, 118, 121, 115, 122, 120, 118,
    123, 119, 126, 122, 121, 119, 119,
  ];
  static const _alerts = <double>[
    4, 6, 3, 5, 8, 4, 2,
    7, 9, 5, 4, 3, 6, 7,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final recentAlerts = ref.watch(recentAlertsProvider);
    final allAlerts = ref.watch(alertsProvider);

    final total = devices.length;
    final online = devices.where((d) => d.status == DeviceStatus.online).length;
    final openAlerts =
        allAlerts.where((a) => a.status == AlertStatus.open).length;
    final healthyPercent = total == 0
        ? 0
        : ((devices.where((d) => d.health == HealthStatus.healthy).length /
                    total) *
                100)
            .round();
    final onlinePercent = total == 0 ? 0 : ((online / total) * 100).round();

    // Live telemetry for THIS machine — shells out to PowerShell on a
    // cadence bound to `heartbeatSeconds` in Settings. On first frame
    // (before the first PowerShell round-trip returns) we fall back to
    // a zero-ish placeholder so the card paints immediately.
    final liveStatus = ref.watch(liveSystemStatusProvider);
    final summaryStatus = liveStatus.maybeWhen(
      data: (s) => s,
      orElse: () => SystemStatus(
        deviceId: '',
        hostname: 'Collecting…',
        os: 'Windows',
        osBuild: '',
        architecture: 'x64',
        cpuName: 'Reading /Processor(_Total)/…',
        cpuCores: 0,
        cpuUsagePercent: 0,
        totalRamGb: 0,
        usedRamGb: 0,
        diskTotalGb: 0,
        diskUsedGb: 0,
        uptimeSeconds: 0,
        batteryPercent: null,
        isCharging: null,
        timestamp: DateTime.now(),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Add Device CTA banner (admin role only) ---
          // Surfaces the enrollment-code workflow the moment the admin
          // lands on the Dashboard instead of forcing them to hunt for
          // the button under the Devices tab.
          const EnrollmentCtaBanner(),
          const SizedBox(height: 20),

          // --- KPI strip ---
          KpiStrip(
            cards: [
              KpiCard(
                icon: Icons.devices_other,
                accent: AppColors.seed,
                label: 'Total Devices',
                value: '$total',
                delta: 'Fleet',
                trend: KpiTrend.flat,
              ),
              KpiCard(
                icon: Icons.wifi_tethering,
                accent: AppColors.success,
                label: 'Online Devices',
                value: '$online',
                delta: '$onlinePercent%',
                trend: onlinePercent >= 90
                    ? KpiTrend.up
                    : (onlinePercent >= 75 ? KpiTrend.flat : KpiTrend.down),
              ),
              KpiCard(
                icon: Icons.notifications_active_outlined,
                accent: AppColors.danger,
                label: 'Active Alerts',
                value: '$openAlerts',
                delta: openAlerts == 0 ? 'All clear' : 'Open',
                trend: openAlerts == 0
                    ? KpiTrend.up
                    : (openAlerts > 10 ? KpiTrend.down : KpiTrend.flat),
              ),
              KpiCard(
                icon: Icons.favorite_outline,
                accent: AppColors.warning,
                label: 'System Health',
                value: '$healthyPercent%',
                delta: healthyPercent >= 90 ? 'Stable' : 'Attention',
                trend: healthyPercent >= 90
                    ? KpiTrend.up
                    : (healthyPercent >= 75 ? KpiTrend.flat : KpiTrend.down),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Activity chart ---
          const ActivityChart(
            onlineSeries: _online,
            alertsSeries: _alerts,
            labels: _labels,
          ),
          const SizedBox(height: 20),

          // --- Two-column: alerts + system summary ---
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 980;
              final left = RecentAlertsPanel(
                alerts: recentAlerts,
                onViewAll: () {},
              );
              final right = SystemSummaryPanel(status: summaryStatus);

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: right),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  const SizedBox(height: 20),
                  right,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
