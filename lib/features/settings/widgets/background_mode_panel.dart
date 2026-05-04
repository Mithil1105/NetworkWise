import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/autostart_service.dart';
import '../../../core/theme/app_colors.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Phase 24 — Settings card that lets the operator toggle "run silently
/// in background at startup" without leaving the app. The toggle writes
/// (or deletes) the HKCU\Software\Microsoft\Windows\CurrentVersion\Run
/// entry that points to the current exe with `--background`.
///
/// Hidden entirely on non-Windows hosts (development on macOS / Linux).
class BackgroundModePanel extends ConsumerWidget {
  const BackgroundModePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    final asyncState = ref.watch(autostartStateProvider);

    return SettingsSection(
      title: 'Background mode',
      subtitle:
          'Run NetworkWise silently at every Windows login — no taskbar entry, '
          'no visible window. The agent still ships heartbeats and tracks '
          'activity exactly as before.',
      icon: Icons.bedtime_outlined,
      children: [
        asyncState.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (err, _) => _ErrorRow(
            message: err.toString(),
            onRetry: () => ref.invalidate(autostartStateProvider),
          ),
          data: (state) => _ToggleRow(state: state),
        ),
        const Divider(height: 1, color: AppColors.divider),
        const _DisclosureRow(),
      ],
    );
  }
}

class _ToggleRow extends ConsumerStatefulWidget {
  const _ToggleRow({required this.state});

  final AutostartState state;

  @override
  ConsumerState<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends ConsumerState<_ToggleRow> {
  bool _busy = false;

  Future<void> _toggle(bool enable) async {
    if (_busy) return;
    setState(() => _busy = true);
    final svc = ref.read(autostartServiceProvider);
    try {
      if (enable) {
        await svc.install();
      } else {
        await svc.uninstall();
      }
      if (!mounted) return;
      ref.invalidate(autostartStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable
              ? 'Background mode enabled — NetworkWise will start hidden at the next login.'
              : 'Background mode disabled — NetworkWise will not auto-start.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update autostart — $err'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final stalePath = s.installed && !s.pointsToCurrentInstall;
    return SettingRow(
      label: 'Run hidden at startup',
      help: stalePath
          ? 'Currently registered, but the path points to a different '
              'install. Toggle off then on to refresh it to this exe.'
          : (s.installed
              ? 'NetworkWise will launch invisibly on every Windows login. '
                  'Use the system tray icon to open the dashboard or quit.'
              : 'When enabled, NetworkWise will launch silently every time '
                  'you sign into Windows. The agent runs in the background '
                  'with a system tray icon — no taskbar entry.'),
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Switch.adaptive(
            value: s.installed && s.pointsToCurrentInstall,
            onChanged: _busy ? null : _toggle,
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline,
                  size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not read the autostart registry entry.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontSize: 11.5, color: AppColors.neutral),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.privacy_tip_outlined,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A hidden agent that captures activity is employee monitoring '
                'territory. Make sure your IT acceptable-use policy is in '
                'force and the user has acknowledged it before enabling. '
                'Disabling later is one click — no admin elevation needed.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
