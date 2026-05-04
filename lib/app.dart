import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/data_service_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/bootstrap_gate.dart';

/// Root of the NetworkWise Windows desktop app.
///
/// Watches [settingsProvider] so theme-mode toggles flip the whole app
/// live, and pipes `heartbeatSeconds` into [IDataService.configureHeartbeat]
/// so the Settings screen's stepper drives the service's real cadence.
class NetworkWiseApp extends ConsumerStatefulWidget {
  const NetworkWiseApp({super.key});

  @override
  ConsumerState<NetworkWiseApp> createState() => _NetworkWiseAppState();
}

class _NetworkWiseAppState extends ConsumerState<NetworkWiseApp> {
  @override
  void initState() {
    super.initState();
    // Prime the service with the initial cadence as soon as the tree
    // is mounted — `dataServiceProvider` is lazy, so the read here is
    // what actually brings it online.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(settingsProvider).heartbeatSeconds;
      ref
          .read(dataServiceProvider)
          .configureHeartbeat(Duration(seconds: initial));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fire the service's configureHeartbeat whenever the stepper moves.
    ref.listen<int>(
      settingsProvider.select((s) => s.heartbeatSeconds),
      (previous, next) {
        ref
            .read(dataServiceProvider)
            .configureHeartbeat(Duration(seconds: next));
      },
    );

    final themeMode =
        ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const BootstrapGate(),
    );
  }
}
