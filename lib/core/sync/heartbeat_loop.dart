import 'dart:async';

import '../models/device_hardware_profile.dart';
import '../models/system_status.dart';
import '../services/device_identity_service.dart';
import '../services/system_probe/i_system_probe.dart';
import 'sync_queue.dart';
import 'sync_queue_provider.dart';

/// Periodically samples the current machine and enqueues a heartbeat
/// write for the Supabase Edge Function to pick up.
///
/// The loop deliberately does *not* hit PostgREST directly — everything
/// goes through [SyncQueue] so a transient offline period just fills
/// the queue instead of losing data. The queue's own drain timer is
/// what ultimately calls the Edge Function.
class HeartbeatLoop {
  HeartbeatLoop({
    required this.probe,
    required this.queue,
    required this.identity,
    Duration interval = const Duration(seconds: 60),
  }) : _interval = interval;

  final ISystemProbe probe;
  final SyncQueue queue;
  final DeviceIdentityService identity;

  Duration _interval;
  Timer? _timer;
  bool _ticking = false;

  /// Seconds between heartbeats. Matches the user's Settings cadence;
  /// call [setInterval] when they change it in the UI.
  Duration get interval => _interval;

  /// Start the loop. Idempotent — calling twice just resets the clock.
  void start() {
    stop();
    _timer = Timer.periodic(_interval, (_) => unawaited(_tick()));
    // Take an immediate sample so the first heartbeat lands within a
    // few seconds of app launch rather than one full cadence later.
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Change the cadence. Safe to call before [start]; the new interval
  /// is picked up on the next tick cycle.
  void setInterval(Duration next) {
    final clamped = Duration(seconds: next.inSeconds.clamp(10, 600));
    if (clamped == _interval) return;
    _interval = clamped;
    if (_timer != null) start();
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final me = identity.current;
      if (me == null) return; // bootstrap hasn't resolved us yet.

      // Sample the live telemetry and the static hardware profile in
      // parallel. The hardware profile carries the LAN IP + MAC + the
      // current hostname — any of those may have drifted since the
      // device was enrolled, so we send them along every tick.
      final results = await Future.wait<Object?>(<Future<Object?>>[
        probe.sample(),
        _safeCaptureHardwareProfile(),
      ]);
      final sample = (results[0] as SystemStatus)
          .copyWith(deviceId: me.deviceUuid);
      final profile = results[1] as DeviceHardwareProfile?;

      await queue.enqueue(
        SyncOpKind.heartbeat,
        systemStatusToSyncJson(sample, profile: profile),
      );
    } catch (_) {
      // Any transient error — next tick will try again.
    } finally {
      _ticking = false;
    }
  }

  /// Hardware profile capture can shell out to PowerShell — treat a
  /// failure as non-fatal so a locked-down endpoint still emits the
  /// telemetry half of the heartbeat.
  Future<DeviceHardwareProfile?> _safeCaptureHardwareProfile() async {
    try {
      return await probe.captureHardwareProfile();
    } catch (_) {
      return null;
    }
  }
}

/// Small helper that lets UI / tests build a deterministic heartbeat
/// without running the probe — useful for golden tests.
SystemStatus synthesiseHeartbeat({
  required String deviceUuid,
  required String hostname,
}) {
  return SystemStatus(
    deviceId: deviceUuid,
    hostname: hostname,
    os: 'Windows',
    osBuild: '',
    architecture: 'x64',
    cpuName: 'synthetic',
    cpuCores: 0,
    cpuUsagePercent: 0,
    totalRamGb: 0,
    usedRamGb: 0,
    diskTotalGb: 0,
    diskUsedGb: 0,
    uptimeSeconds: 0,
    batteryPercent: null,
    isCharging: null,
    timestamp: DateTime.now().toUtc(),
  );
}
