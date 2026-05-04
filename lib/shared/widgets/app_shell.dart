import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/data_service_provider.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/devices/devices_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/security/security_screen.dart';
import '../../features/settings/settings_screen.dart';
import 'app_sidebar.dart';
import 'app_top_bar.dart';
import 'nav_destination.dart';

/// The root layout: persistent sidebar + top bar + swappable content area.
///
/// Uses a simple [IndexedStack] driven by local state so every screen
/// keeps its scroll/state while navigating. We'll migrate selection
/// state to Riverpod in Phase 10.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selected = 0;
  bool _refreshing = false;

  static const List<AppNavDestination> _destinations = [
    AppNavDestination(
      label: AppStrings.navDashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    AppNavDestination(
      label: AppStrings.navDevices,
      icon: Icons.devices_other_outlined,
      selectedIcon: Icons.devices_other,
    ),
    AppNavDestination(
      label: AppStrings.navSecurity,
      icon: Icons.shield_outlined,
      selectedIcon: Icons.shield,
    ),
    AppNavDestination(
      label: AppStrings.navAlerts,
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
    ),
    AppNavDestination(
      label: AppStrings.navReports,
      icon: Icons.insert_chart_outlined,
      selectedIcon: Icons.insert_chart,
    ),
    AppNavDestination(
      label: AppStrings.navSettings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  final List<Widget> _pages = const [
    DashboardScreen(),
    DevicesScreen(),
    SecurityScreen(),
    AlertsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  final List<String> _subtitles = const [
    'Overview of your fleet',
    'All managed endpoints',
    'Antivirus, firewall & activation',
    'Triage and resolve incidents',
    'Exportable insights',
    'Application configuration',
  ];

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Refreshing fleet data…'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 30),
      ),
    );

    try {
      await ref.read(dataServiceProvider).refresh();
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Fleet data refreshed'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Refresh failed — $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            destinations: _destinations,
            selectedIndex: _selected,
            onSelected: (i) => setState(() => _selected = i),
          ),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  title: _destinations[_selected].label,
                  subtitle: _subtitles[_selected],
                  onRefresh: _refreshing ? null : () => _handleRefresh(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selected,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
