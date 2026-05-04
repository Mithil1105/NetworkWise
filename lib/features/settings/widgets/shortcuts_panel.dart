import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/shortcut_service.dart';
import '../../../core/theme/app_colors.dart';
import 'setting_row.dart';
import 'settings_section.dart';

/// Phase 25 — surfaces buttons to drop NetworkWise on the Desktop and
/// in the Start Menu, plus an instruction strip for pinning to the
/// taskbar (which Windows requires the user to do via right-click,
/// since Microsoft removed programmatic taskbar pinning in Windows 10).
///
/// Hidden on non-Windows hosts.
class ShortcutsPanel extends ConsumerWidget {
  const ShortcutsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isWindows) return const SizedBox.shrink();
    final asyncState = ref.watch(shortcutStateProvider);

    return SettingsSection(
      title: 'Shortcuts & pinning',
      subtitle:
          'Put NetworkWise where staff can find it — Desktop, Start Menu, '
          'or pinned to the taskbar.',
      icon: Icons.push_pin_outlined,
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
            onRetry: () => ref.invalidate(shortcutStateProvider),
          ),
          data: (state) => Column(
            children: [
              _ShortcutRow(
                label: 'Desktop shortcut',
                help:
                    'Adds a NetworkWise icon to your desktop. Double-click to '
                    'open the dashboard normally.',
                installed: state.desktop,
                onCreate: () => ref
                    .read(shortcutServiceProvider)
                    .createDesktopShortcut(),
                onRemove: () => ref
                    .read(shortcutServiceProvider)
                    .removeDesktopShortcut(),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _ShortcutRow(
                label: 'Start Menu shortcut',
                help:
                    'Adds a NetworkWise entry under the Start Menu so the user '
                    'can launch from the Windows search box.',
                installed: state.startMenu,
                onCreate: () => ref
                    .read(shortcutServiceProvider)
                    .createStartMenuShortcut(),
                onRemove: () => ref
                    .read(shortcutServiceProvider)
                    .removeStartMenuShortcut(),
              ),
              const Divider(height: 1, color: AppColors.divider),
              const _TaskbarInstruction(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends ConsumerStatefulWidget {
  const _ShortcutRow({
    required this.label,
    required this.help,
    required this.installed,
    required this.onCreate,
    required this.onRemove,
  });

  final String label;
  final String help;
  final bool installed;
  final Future<void> Function() onCreate;
  final Future<void> Function() onRemove;

  @override
  ConsumerState<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends ConsumerState<_ShortcutRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action,
      {required String okMessage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(shortcutStateProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMessage), duration: const Duration(seconds: 2)),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shortcut update failed — $err'),
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
    return SettingRow(
      label: widget.label,
      help: widget.help,
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (widget.installed)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(widget.onRemove, okMessage: 'Shortcut removed'),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(widget.onCreate, okMessage: 'Shortcut created'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create'),
            ),
        ],
      ),
    );
  }
}

class _TaskbarInstruction extends StatelessWidget {
  const _TaskbarInstruction();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  'Pin to taskbar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Microsoft removed automatic taskbar pinning in Windows 10 — '
              'every app has to do it the same way:',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            _InstructionStep(
              n: 1,
              text: 'Create the Start Menu shortcut above.',
              theme: theme,
            ),
            _InstructionStep(
              n: 2,
              text: 'Open Start, search for "NetworkWise".',
              theme: theme,
            ),
            _InstructionStep(
              n: 3,
              text: 'Right-click the result → "Pin to taskbar".',
              theme: theme,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tip — once pinned, you can right-click the taskbar icon → '
                    'Properties → Run minimised to keep launches discreet.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(
                      text:
                          'Right-click the NetworkWise Start Menu entry and choose Pin to taskbar.',
                    ));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Instruction copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy steps'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.n,
    required this.text,
    required this.theme,
  });

  final int n;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: BoxDecoration(
              color: AppColors.info,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
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
                  'Could not check the shortcut state.',
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
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.neutral,
            ),
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
