import 'dart:async';

import '../models/security_status.dart';
import '../services/device_identity_service.dart';
import '../services/security_probe/i_security_probe.dart';
import 'sync_queue.dart';
import 'sync_queue_provider.dart';

/// Periodically captures a full security-posture sample on the current
/// machine and enqueues a [SyncOpKind.securitySnapshot] so the Supabase
/// `report-snapshot` Edge Function can append a new `security_status`
/// row and refresh the multi-AV inventory in `security_antivirus_products`.
///
/// The security probe is noticeably heavier than the system probe —
/// it shells out to PowerShell for WSC, Defender, firewall, BitLocker,
/// activation, Windows Update AND vendor registry scans — so the loop
/// runs on a slower cadence than the heartbeat loop. The default is 10
/// minutes which matches the AV-inventory refresh rate a chartered
/// accountancy firm needs for license-expiry tracking, without burning
/// CPU on machines running third-party scan shields.
class SecurityLoop {
  SecurityLoop({
    required this.probe,
    required this.queue,
    required this.identity,
    Duration interval = const Duration(minutes: 10),
  }) : _interval = interval;

  final ISecurityProbe probe;
  final SyncQueue queue;
  final DeviceIdentityService identity;

  Duration _interval;
  Timer? _timer;
  bool _ticking = false;

  Duration get interval => _interval;

  /// Start the loop. Idempotent — calling twice resets the clock.
  /// An immediate tick fires so the first security posture lands within
  /// a few seconds of app launch rather than after one full cadence.
  void start() {
    stop();
    _timer = Timer.periodic(_interval, (_) => unawaited(_tick()));
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Change cadence; the new interval is picked up on the next tick.
  void setInterval(Duration next) {
    // Clamp between 60s and 1h — shorter than a minute shells out too
    // often, longer than an hour misses license-expiry changes that
    // matter for renewal reminders.
    final clamped = Duration(seconds: next.inSeconds.clamp(60, 3600));
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

      final sample = await probe.sample();
      if (sample.deviceId.isNotEmpty && sample.deviceId == me.deviceUuid) {
        // Already keyed correctly — rare, but skip the copyWith.
        await queue.enqueue(
          SyncOpKind.securitySnapshot,
          securityStatusToSyncJson(sample),
        );
        return;
      }
      final keyed = sample.copyWith(deviceId: me.deviceUuid);
      await queue.enqueue(
        SyncOpKind.securitySnapshot,
        securityStatusToSyncJson(keyed),
      );
    } catch (_) {
      // Any transient error — the next tick will try again.
      // Non-retriable failures never reach us because the probe wraps
      // every individual query in its own PowerShell try/catch.
    } finally {
      _ticking = false;
    }
  }
}

/// Synthesise a deterministic posture for golden tests / first-paint
/// fallbacks where running the real probe isn't desirable (e.g. unit
/// tests on CI with no PowerShell, or the admin role).
SecurityStatus synthesiseSecurity({required String deviceUuid}) {
  return SecurityStatus(
    deviceId: deviceUuid,
    antivirusName: 'Unknown',
    antivirusEnabled: false,
    antivirusUpToDate: false,
    realTimeProtection: false,
    lastScanAt: null,
    firewallDomain: FirewallState.unknown,
    firewallPrivate: FirewallState.unknown,
    firewallPublic: FirewallState.unknown,
    windowsActivated: false,
    bitLockerEnabled: false,
    lastUpdateCheck: null,
  );
}
