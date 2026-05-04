import '../models/alert.dart';
import '../models/device.dart';
import '../../features/devices/data/mock_device_detail.dart';

/// Contract for the data layer behind every Riverpod provider.
///
/// The concrete implementation ([MockDataService] today, a real REST /
/// gRPC / WMI client tomorrow) is responsible for:
///   * maintaining an in-memory snapshot of the fleet and alert feed,
///   * ticking a heartbeat that advances device `lastSeen` timestamps,
///   * emitting a [changes] event every time that snapshot moves,
///   * accepting targeted mutations (ack / resolve alerts).
///
/// Providers subscribe to [changes] and re-read the snapshot — keeping
/// the UI surface fully synchronous without a single `FutureBuilder`.
abstract class IDataService {
  /// Starts internal timers and primes any asynchronous caches.
  /// Must be idempotent; re-calling has no effect.
  Future<void> start();

  /// Cancels timers and closes the [changes] stream. Must not throw if
  /// called repeatedly or before [start].
  Future<void> dispose();

  /// Broadcast stream that fires after every internal mutation —
  /// heartbeat tick, alert status change, or future fleet mutation.
  /// The event payload is intentionally `void`; subscribers re-read.
  Stream<void> get changes;

  // -------- Snapshot accessors (synchronous; cheap) --------

  /// Current fleet snapshot. Returned list is immutable from the
  /// caller's perspective; call again after a [changes] event for a
  /// fresh copy.
  List<Device> getDevices();

  /// Full alerts feed — most-recent first.
  List<Alert> getAlerts();

  /// Per-device drill-down for the detail screen & security rollup.
  MockDeviceDetail getDeviceDetail(String deviceId);

  // -------- Mutations --------

  /// Moves a single alert into [AlertStatus.acknowledged]. No-op if the
  /// id is unknown or already acknowledged.
  void acknowledgeAlert(String alertId);

  /// Moves a single alert into [AlertStatus.resolved]. No-op if the id
  /// is unknown or already resolved.
  void resolveAlert(String alertId);

  /// Adjust the heartbeat cadence. The Settings screen drives this via
  /// `AppSettings.heartbeatSeconds`. Safe to call before [start]; the
  /// new interval is picked up on the next tick.
  void configureHeartbeat(Duration interval);

  /// Force-refresh the snapshot on demand (bound to the top-bar refresh
  /// button). Implementations should:
  ///   * re-read devices + alerts + security from the backing store,
  ///   * emit a [changes] event so every subscribed widget repaints,
  ///   * return normally even if the fetch fails — the UI keeps the
  ///     last-known snapshot and surfaces the error via a Future.
  Future<void> refresh();
}
