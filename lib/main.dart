import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/bootstrap_provider.dart';
import 'core/bootstrap/device_bootstrap.dart';
import 'core/config/env.dart';
import 'core/services/data_service_provider.dart';
import 'core/services/supabase_service.dart';
import 'core/sync/heartbeat_loop_provider.dart';
import 'core/sync/security_loop_provider.dart';
import 'core/sync/sync_queue_provider.dart';

Future<void> main() async {
  // Ensure the binding is up before any plugin call (dotenv, Supabase,
  // secure storage, shared_preferences all require it).
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables from the bundled `.env` asset.
  //    Must complete before SupabaseService.initialize() is called.
  await Env.load();

  // 2. Bring the Supabase SDK online with the URL + anon key from env.
  await SupabaseService.initialize();

  // 3. Build a ProviderContainer up-front so we can drive bootstrap +
  //    sync-queue wiring before the widget tree exists. UncontrolledProviderScope
  //    re-uses the same container once we hand off to runApp.
  final container = ProviderContainer();

  // 4. Run the device bootstrap (no-op in mock mode). We intentionally
  //    do not await — the splash screen listens to `bootstrapProvider`
  //    and shows progress / retry UI. Awaiting would black-box the user.
  if (container.read(dataSourceModeProvider) == DataSourceMode.supabase) {
    // Prime the sync queue so any queued writes from a previous
    // session are replayed once registration completes.
    // ignore: unawaited_futures
    _wireSyncQueue(container);

    // Kick the bootstrap AsyncNotifier — this is what actually runs
    // `DeviceBootstrap.run()` in the background. Once it resolves to
    // `ready`, the heartbeat loop is started so telemetry begins
    // flowing without any further UI interaction.
    // ignore: unawaited_futures
    _wireBootstrapAndHeartbeat(container);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NetworkWiseApp(),
    ),
  );
}

/// Load the persisted queue and attach the executor once repositories
/// are available. This is separated from the main fast-path so a cold
/// start can render the splash without waiting on disk.
Future<void> _wireSyncQueue(ProviderContainer container) async {
  final queue = container.read(syncQueueProvider);
  await queue.load();
  queue.start(container.read(syncQueueExecutorProvider));
}

/// Bring up bootstrap, then — once the endpoint is registered — start
/// the heartbeat + security loops so PowerShell telemetry begins hitting
/// the sync queue at the configured cadences. The security loop is
/// only started on the endpoint role; the admin dashboard has no
/// reason to probe its own Windows posture (and in fact the admin may
/// be running on a locked-down machine where WSC queries would fail).
Future<void> _wireBootstrapAndHeartbeat(ProviderContainer container) async {
  try {
    final result = await container.read(bootstrapProvider.future);
    if (result.phase != BootstrapPhase.ready) return;

    // Fire-and-forget — the loop starts its own Timer.periodic.
    container.read(heartbeatLoopProvider).start();

    // Security posture is an endpoint concern only — the admin role
    // just reads what endpoints publish. Skipping this on admin also
    // avoids wasting CPU on PowerShell shell-outs from the dashboard.
    if (!Env.isAdminRole) {
      container.read(securityLoopProvider).start();
    }
  } catch (_) {
    // Surfaced to the UI via the `bootstrapProvider` state; nothing to
    // do here besides not crash the app boot.
  }
}
