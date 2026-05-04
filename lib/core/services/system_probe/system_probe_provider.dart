import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/system_status.dart';
import '../../providers/settings_provider.dart';
import '../device_identity_provider.dart';
import 'i_system_probe.dart';
import 'windows_system_probe.dart';

/// Singleton probe for the lifetime of the ProviderScope. Keeping it a
/// singleton means we don't leak a PowerShell process per widget build.
final systemProbeProvider = Provider<ISystemProbe>((ref) {
  return WindowsSystemProbe();
});

/// Live, polling stream of the current machine's telemetry.
///
/// The polling interval piggybacks on `heartbeatSeconds` from the
/// Settings screen — the user's cadence preference controls both how
/// often we push telemetry to Supabase and how often the Dashboard
/// refreshes. That keeps the mental model simple and avoids a rogue
/// second timer burning battery on laptops.
///
/// The first emission is synchronous-ish — we take a sample immediately
/// on subscribe so the widget doesn't paint an empty card.
final liveSystemStatusProvider = StreamProvider<SystemStatus>((ref) {
  final probe = ref.watch(systemProbeProvider);
  final settings = ref.watch(settingsProvider);
  final identity = ref.watch(deviceIdentityProvider).valueOrNull;

  final interval = Duration(seconds: settings.heartbeatSeconds.clamp(5, 600));

  final controller = StreamController<SystemStatus>();

  Future<void> tick() async {
    try {
      final sample = await probe.sample();
      if (!controller.isClosed) {
        // Patch in the current device UUID if bootstrap has resolved
        // one — downstream code uses it as the correlation key for
        // heartbeat writes.
        final withId = identity == null
            ? sample
            : sample.copyWith(deviceId: identity.deviceUuid);
        controller.add(withId);
      }
    } catch (_) {
      // Never propagate — keep the stream alive so the next tick gets
      // a fresh chance.
    }
  }

  // Prime the stream.
  // ignore: unawaited_futures
  tick();

  final timer = Timer.periodic(interval, (_) {
    // ignore: unawaited_futures
    tick();
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
