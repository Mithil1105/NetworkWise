import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/alert.dart';
import '../../core/providers/alerts_provider.dart';
import 'widgets/alert_list.dart';
import 'widgets/alerts_kpi_strip.dart';
import 'widgets/alerts_toolbar.dart';

/// Fleet-wide alerts feed, backed end-to-end by Riverpod providers.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final filtered = ref.watch(filteredAlertsProvider);
    final notifier = ref.read(alertsProvider.notifier);

    final search = ref.watch(alertSearchProvider);
    final statusFilter = ref.watch(alertStatusFilterProvider);
    final categoryFilter = ref.watch(alertCategoryFilterProvider);
    final severities = ref.watch(alertSeveritiesProvider);

    void toggleSeverity(AlertSeverity s) {
      final current = {...severities};
      if (current.contains(s)) {
        current.remove(s);
      } else {
        current.add(s);
      }
      ref.read(alertSeveritiesProvider.notifier).state = current;
    }

    void clearAll() {
      ref.read(alertSearchProvider.notifier).state = '';
      ref.read(alertStatusFilterProvider.notifier).state = null;
      ref.read(alertCategoryFilterProvider.notifier).state = null;
      ref.read(alertSeveritiesProvider.notifier).state = <AlertSeverity>{};
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertsKpiStrip(alerts: alerts),
          const SizedBox(height: 20),
          AlertsToolbar(
            search: search,
            onSearchChanged: (v) =>
                ref.read(alertSearchProvider.notifier).state = v,
            statusFilter: statusFilter,
            onStatusChanged: (v) =>
                ref.read(alertStatusFilterProvider.notifier).state = v,
            categoryFilter: categoryFilter,
            onCategoryChanged: (v) =>
                ref.read(alertCategoryFilterProvider.notifier).state = v,
            selectedSeverities: severities,
            onSeverityToggle: toggleSeverity,
            matchCount: filtered.length,
            totalCount: alerts.length,
            onClearAll: clearAll,
          ),
          const SizedBox(height: 16),
          AlertList(
            alerts: filtered,
            onAcknowledge: (a) => notifier.acknowledge(a.id),
            onResolve: (a) => notifier.resolve(a.id),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
