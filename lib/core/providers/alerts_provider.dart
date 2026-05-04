import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../services/data_service_provider.dart';

/// Notifier mirroring the alert feed from [IDataService]. `build`
/// subscribes to the service's `changes` stream so ack/resolve made
/// anywhere in the app (or service-driven heartbeat inserts in a
/// future revision) flow through a single source of truth.
class AlertsNotifier extends Notifier<List<Alert>> {
  @override
  List<Alert> build() {
    final service = ref.watch(dataServiceProvider);
    final sub = service.changes.listen((_) {
      state = service.getAlerts();
    });
    ref.onDispose(sub.cancel);
    return service.getAlerts();
  }

  /// Flips a single alert to a new status via the service. The service
  /// will emit on `changes` and `build`'s listener republishes.
  void setStatus(String alertId, AlertStatus status) {
    final service = ref.read(dataServiceProvider);
    switch (status) {
      case AlertStatus.acknowledged:
        service.acknowledgeAlert(alertId);
        break;
      case AlertStatus.resolved:
        service.resolveAlert(alertId);
        break;
      case AlertStatus.open:
        // Currently no UX path reverts an alert to open; the service
        // is intentionally forward-only on status. If this becomes a
        // requirement, extend IDataService accordingly.
        break;
    }
  }

  void acknowledge(String alertId) =>
      ref.read(dataServiceProvider).acknowledgeAlert(alertId);

  void resolve(String alertId) =>
      ref.read(dataServiceProvider).resolveAlert(alertId);
}

final alertsProvider =
    NotifierProvider<AlertsNotifier, List<Alert>>(AlertsNotifier.new);

// ---------------- filter state ----------------

final alertSearchProvider = StateProvider<String>((ref) => '');

final alertStatusFilterProvider =
    StateProvider<AlertStatus?>((ref) => null);

final alertCategoryFilterProvider =
    StateProvider<AlertCategory?>((ref) => null);

final alertSeveritiesProvider =
    StateProvider<Set<AlertSeverity>>((ref) => <AlertSeverity>{});

// ---------------- derived ----------------

/// Applies the active filters / search to the full alerts list.
final filteredAlertsProvider = Provider<List<Alert>>((ref) {
  final alerts = ref.watch(alertsProvider);
  final q = ref.watch(alertSearchProvider).trim().toLowerCase();
  final statusFilter = ref.watch(alertStatusFilterProvider);
  final categoryFilter = ref.watch(alertCategoryFilterProvider);
  final severities = ref.watch(alertSeveritiesProvider);

  return alerts.where((a) {
    if (statusFilter != null && a.status != statusFilter) return false;
    if (categoryFilter != null && a.category != categoryFilter) return false;
    if (severities.isNotEmpty && !severities.contains(a.severity)) {
      return false;
    }
    if (q.isEmpty) return true;
    final haystack = [
      a.title,
      a.message,
      a.source ?? '',
      a.deviceId ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }).toList();
});

/// The 5 most-recent alerts — convenience slice used by the dashboard.
final recentAlertsProvider = Provider<List<Alert>>((ref) {
  final alerts = ref.watch(alertsProvider);
  if (alerts.length <= 5) return alerts;
  return alerts.sublist(0, 5);
});
