import '../models/alert.dart';

/// Contract for reading + writing the **alerts** table.
///
/// The repository exposes three distinct writers because the Edge
/// Functions enforce different validation rules on each:
///   * [reportAlert] — create a new alert (severity + category enums
///     validated by `report-alert`).
///   * [acknowledgeAlert] / [resolveAlert] — state transitions handled
///     by `update-alert-status`, which enforces the legal transition
///     graph (open → acknowledged → resolved).
abstract class IAlertsRepository {
  /// Full alert feed, most recent first. Filtering (by severity /
  /// status / device) is applied in the providers layer — the
  /// repository returns the raw stream of rows.
  Future<List<Alert>> listAlerts();

  /// Broadcast trigger. Supabase implementation subscribes to the
  /// `alerts` table via Realtime; the mock implementation relays its
  /// internal change stream.
  Stream<void> watchAlerts();

  /// Create a new alert for a device.
  Future<String> reportAlert({
    required String deviceId,
    required String registrationSecret,
    required String title,
    String? message,
    required AlertSeverity severity,
    required AlertCategory category,
    String? source,
    DateTime? occurredAt,
  });

  /// Mark an alert as acknowledged. Throws if the transition is
  /// illegal (e.g. trying to acknowledge a resolved alert).
  Future<void> acknowledgeAlert({
    required String deviceId,
    required String registrationSecret,
    required String alertId,
    String? actor,
  });

  /// Mark an alert as resolved.
  Future<void> resolveAlert({
    required String deviceId,
    required String registrationSecret,
    required String alertId,
    String? actor,
  });
}
