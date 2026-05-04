import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_identity_provider.dart';
import '../services/security_probe/security_probe_provider.dart';
import 'security_loop.dart';
import 'sync_queue_provider.dart';

/// Builds a single [SecurityLoop] for the lifetime of the app.
///
/// The loop is NOT started from this provider — `main.dart` kicks it
/// after bootstrap resolves the device identity so we never publish a
/// security posture for a machine that hasn't finished enrolment.
///
/// Unlike [heartbeatLoopProvider] the cadence is fixed (10 min) rather
/// than wired to [settingsProvider.heartbeatSeconds]; the user's
/// heartbeat preference is for system telemetry (CPU / RAM / uptime),
/// while the security posture has its own cadence that trades extra
/// latency on license-expiry changes for much lower CPU overhead.
final securityLoopProvider = Provider<SecurityLoop>((ref) {
  final probe = ref.watch(securityProbeProvider);
  final queue = ref.watch(syncQueueProvider);
  final identity = ref.watch(deviceIdentityServiceProvider);

  final loop = SecurityLoop(
    probe: probe,
    queue: queue,
    identity: identity,
  );

  ref.onDispose(loop.stop);
  return loop;
});
