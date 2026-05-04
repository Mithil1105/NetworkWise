import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/about_card.dart';
import 'widgets/admins_panel.dart';
import 'widgets/background_mode_panel.dart';
import 'widgets/enrollment_code_panel.dart';
import 'widgets/numeric_stepper.dart';
import 'widgets/setting_row.dart';
import 'widgets/settings_section.dart';
import 'widgets/shortcuts_panel.dart';
import 'widgets/theme_mode_selector.dart';

/// Phase 9 + 10 — user-tunable preferences backed by the
/// [settingsProvider] Riverpod notifier.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text(
          'This restores heartbeat, thresholds and theme to the factory '
          'defaults. Device data is unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings restored to defaults'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- Device enrollment (admin-only) ----------
          if (Env.isAdminRole) ...[
            const EnrollmentCodePanel(),
            const SizedBox(height: 20),
            const AdminsPanel(),
            const SizedBox(height: 20),
          ],

          // ---------- Appearance ----------
          SettingsSection(
            title: 'Appearance',
            subtitle: 'Control how NetworkWise looks on this device',
            icon: Icons.palette_outlined,
            children: [
              SettingRow(
                label: 'Theme mode',
                help:
                    'Switch between light and dark UI, or follow the Windows '
                    'system setting automatically.',
                control: ThemeModeSelector(
                  value: settings.themeMode,
                  onChanged: notifier.setThemeMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---------- Monitoring ----------
          SettingsSection(
            title: 'Monitoring',
            subtitle:
                'Cadence and alert thresholds used when evaluating fleet '
                'telemetry',
            icon: Icons.monitor_heart_outlined,
            children: [
              SettingRow(
                label: 'Heartbeat interval',
                help:
                    'How often each device reports back to the console. '
                    'Lower values increase network chatter; higher values '
                    'delay alerting.',
                control: NumericStepper(
                  value: settings.heartbeatSeconds.toDouble(),
                  min: 10,
                  max: 600,
                  step: 5,
                  suffix: 'sec',
                  onChanged: (v) =>
                      notifier.setHeartbeatSeconds(v.round()),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              SettingRow(
                label: 'Storage warning threshold',
                help:
                    'Devices whose system drive exceeds this percentage are '
                    'flagged on the Dashboard and Devices list.',
                control: NumericStepper(
                  value: settings.storageThresholdPercent,
                  min: 50,
                  max: 99,
                  step: 1,
                  suffix: '%',
                  isDouble: true,
                  onChanged: notifier.setStorageThresholdPercent,
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              SettingRow(
                label: 'CPU warning threshold',
                help:
                    'Sustained CPU utilisation above this level triggers a '
                    'performance alert.',
                control: NumericStepper(
                  value: settings.cpuWarningPercent,
                  min: 50,
                  max: 99,
                  step: 1,
                  suffix: '%',
                  isDouble: true,
                  onChanged: notifier.setCpuWarningPercent,
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              SettingRow(
                label: 'Memory warning threshold',
                help:
                    'RAM utilisation threshold that surfaces a "High memory" '
                    'alert against the device.',
                control: NumericStepper(
                  value: settings.memoryWarningPercent,
                  min: 50,
                  max: 99,
                  step: 1,
                  suffix: '%',
                  isDouble: true,
                  onChanged: notifier.setMemoryWarningPercent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---------- Background mode (Windows only) ----------
          // Only the endpoint build typically runs hidden — admins want
          // to see the dashboard. We still expose the toggle on admin
          // installs in case the operator wants to keep the dashboard
          // alive across reboots; the autostart entry just opens the
          // window normally on those builds.
          const BackgroundModePanel(),
          const SizedBox(height: 20),

          // ---------- Shortcuts & pinning (Windows only) ----------
          const ShortcutsPanel(),
          const SizedBox(height: 20),

          // ---------- Data ----------
          SettingsSection(
            title: 'Data',
            subtitle: 'Reset preferences or review application information',
            icon: Icons.storage_outlined,
            children: [
              SettingRow(
                label: 'Reset all settings',
                help:
                    'Restores heartbeat, thresholds and theme to factory '
                    'defaults. Does not clear device data.',
                control: OutlinedButton.icon(
                  onPressed: () => _confirmReset(context, ref),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset to defaults'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---------- About ----------
          const AboutCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
