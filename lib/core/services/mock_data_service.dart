import 'dart:async';
import 'dart:math' as math;

import '../../features/alerts/data/mock_fleet_alerts.dart';
import '../../features/devices/data/mock_device_detail.dart';
import '../../features/devices/data/mock_devices.dart';
import '../constants/app_constants.dart';
import '../models/alert.dart';
import '../models/device.dart';
import 'i_data_service.dart';

/// In-memory implementation of [IDataService] that simulates a live
/// console by:
///
///   * Seeding its fleet snapshot from [MockDevices] and the alert
///     feed from [MockFleetAlerts].
///   * Ticking a [Timer.periodic] on the configured heartbeat cadence —
///     each tick nudges `lastSeen` forward on every online device and
///     emits a [changes] event so timestamps re-render.
///   * Accepting targeted alert status mutations that re-emit.
///
/// This class is intentionally stateful but hidden behind the
/// interface — Phase 11+ can swap it for a WMI / REST client without
/// touching a single screen.
class MockDataService implements IDataService {
  MockDataService();

  final StreamController<void> _changes = StreamController<void>.broadcast();

  List<Device> _devices = const [];
  List<Alert> _alerts = const [];

  Timer? _heartbeatTimer;
  Duration _heartbeat =
      const Duration(seconds: AppConstants.defaultHeartbeatSeconds);
  bool _started = false;
  bool _disposed = false;

  final math.Random _rng = math.Random(42);

  // --------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------

  @override
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _devices = [...MockDevices.all];
    _alerts = MockFleetAlerts.sortedByRecency();
    _armTimer();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  // --------------------------------------------------------------
  // Snapshot accessors
  // --------------------------------------------------------------

  @override
  List<Device> getDevices() => List<Device>.unmodifiable(_devices);

  @override
  List<Alert> getAlerts() => List<Alert>.unmodifiable(_alerts);

  @override
  MockDeviceDetail getDeviceDetail(String deviceId) {
    // Detail is deterministic per id; no need to cache here.
    return MockDeviceDetail.forDeviceId(deviceId);
  }

  // --------------------------------------------------------------
  // Mutations
  // --------------------------------------------------------------

  @override
  void acknowledgeAlert(String alertId) =>
      _setAlertStatus(alertId, AlertStatus.acknowledged);

  @override
  void resolveAlert(String alertId) =>
      _setAlertStatus(alertId, AlertStatus.resolved);

  void _setAlertStatus(String alertId, AlertStatus next) {
    if (_disposed) return;
    var mutated = false;
    final updated = <Alert>[
      for (final a in _alerts)
        if (a.id == alertId && a.status != next)
          (() {
            mutated = true;
            return a.copyWith(status: next);
          })()
        else
          a,
    ];
    if (!mutated) return;
    _alerts = updated;
    _emit();
  }

  @override
  void configureHeartbeat(Duration interval) {
    if (_disposed) return;
    // Clamp defensively — settings already clamps to [10, 600], but keep
    // the service safe in isolation too.
    final clampedSeconds = interval.inSeconds.clamp(5, 3600);
    final next = Duration(seconds: clampedSeconds);
    if (next == _heartbeat && _heartbeatTimer != null) return;
    _heartbeat = next;
    _armTimer();
  }

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    // Mock mode has no backing store to re-read — the best we can do is
    // force an immediate heartbeat tick so the UI advances `lastSeen`.
    _onHeartbeat();
    _emit();
  }

  // --------------------------------------------------------------
  // Internals
  // --------------------------------------------------------------

  void _armTimer() {
    _heartbeatTimer?.cancel();
    if (_disposed || !_started) return;
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _onHeartbeat());
  }

  /// Simulates a fleet-wide check-in. Every online device nudges
  /// `lastSeen` forward with a tiny jitter so the UI's relative
  /// timestamps feel alive; offline devices stay stale on purpose.
  void _onHeartbeat() {
    if (_disposed) return;
    final now = DateTime.now();
    var anyChanged = false;

    final next = <Device>[];
    for (final d in _devices) {
      if (d.status == DeviceStatus.online) {
        // A few ms of jitter so rows don't all snap to the same second.
        final jitterMs = _rng.nextInt(1500);
        final fresh = now.subtract(Duration(milliseconds: jitterMs));
        next.add(
          d.copyWith(
            lastSeen: fresh,
            uptimeSeconds: d.uptimeSeconds + _heartbeat.inSeconds,
          ),
        );
        anyChanged = true;
      } else {
        next.add(d);
      }
    }

    if (anyChanged) {
      _devices = next;
      _emit();
    }
  }

  void _emit() {
    if (_disposed || _changes.isClosed) return;
    _changes.add(null);
  }
}
