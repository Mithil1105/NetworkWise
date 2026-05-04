import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/device_identity_provider.dart';
import '../services/system_probe/system_probe_provider.dart';
import 'heartbeat_loop.dart';
import 'sync_queue_provider.dart';

/// Builds a single [HeartbeatLoop] for the lifetime of the app and
/// keeps its cadence in lockstep with [settingsProvider.heartbeatSeconds].
///
/// The loop is *not* started here — `main.dart` kicks it after bootstrap
/// completes so we don't publish heartbeats for a machine that isn't
/// registered yet.
final heartbeatLoopProvider = Provider<HeartbeatLoop>((ref) {
  final probe = ref.watch(systemProbeProvider);
  final queue = ref.watch(syncQueueProvider);
  final identity = ref.watch(deviceIdentityServiceProvider);
  final settings = ref.watch(settingsProvider);

  final loop = HeartbeatLoop(
    probe: probe,
    queue: queue,
    identity: identity,
    interval: Duration(seconds: settings.heartbeatSeconds),
  );

  // React to cadence changes from the Settings screen.
  ref.listen(settingsProvider, (prev, next) {
    if (prev?.heartbeatSeconds != next.heartbeatSeconds) {
      loop.setInterval(Duration(seconds: next.heartbeatSeconds));
    }
  });

  ref.onDispose(loop.stop);
  return loop;
});
