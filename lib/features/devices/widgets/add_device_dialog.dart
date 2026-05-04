import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/organization_provider.dart';
import '../../../core/admin/organization_summary.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';

/// Step-by-step enrollment guide launched from the "Add device"
/// button on the Devices screen. Reuses [organizationSummaryProvider]
/// so the code always matches whatever is shown on the Settings panel.
///
/// Endpoint installs don't get this — only admins can see / rotate
/// the enrollment code.
Future<void> showAddDeviceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _AddDeviceDialog(),
  );
}

class _AddDeviceDialog extends ConsumerStatefulWidget {
  const _AddDeviceDialog();

  @override
  ConsumerState<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends ConsumerState<_AddDeviceDialog> {
  bool _reveal = false;
  bool _rotating = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(organizationSummaryProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key_outlined, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(child: Text('Enroll a new Windows PC')),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () =>
                ref.read(organizationSummaryProvider.notifier).refresh(),
          ),
          data: (summary) => _Body(
            summary: summary,
            reveal: _reveal,
            rotating: _rotating,
            onToggleReveal: () => setState(() => _reveal = !_reveal),
            onCopy: () => _copy(summary?.enrollmentCode),
            onRotate: () => _rotate(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _copy(String? code) async {
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enrollment code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rotate enrollment code?'),
        content: const Text(
          'The existing code will stop working immediately. Any new '
          'Windows PC will need the new code to enroll.\n\n'
          'Already-enrolled devices are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rotate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _rotating = true);
    try {
      await ref
          .read(organizationSummaryProvider.notifier)
          .rotateEnrollmentCode();
      if (!mounted) return;
      setState(() => _reveal = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment code rotated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rotate failed — $err'),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }
}

// ---------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.summary,
    required this.reveal,
    required this.rotating,
    required this.onToggleReveal,
    required this.onCopy,
    required this.onRotate,
  });

  final OrganizationSummary? summary;
  final bool reveal;
  final bool rotating;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          Env.isAdminRole
              ? 'Sign in as an admin from Settings → Admin Access to '
                  'view your organisation\'s enrollment code.'
              : 'Only admins can share the enrollment code. Ask your '
                  'dashboard operator for the current code, then paste '
                  'it on the first-run screen of the new Windows PC.',
          style: const TextStyle(color: AppColors.neutral, fontSize: 13),
        ),
      );
    }

    final code = summary!.enrollmentCode ?? '';
    final masked = _maskCode(code);
    final shown = reveal ? code : masked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Share this rolling code with any new Windows PC — it is the '
          'one secret the endpoint needs to join your fleet.',
          style: TextStyle(fontSize: 13, color: AppColors.neutral),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, size: 22, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  shown.isEmpty ? '—' : shown,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: reveal ? 'Hide code' : 'Reveal code',
                icon: Icon(
                  reveal
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: code.isEmpty ? null : onToggleReveal,
              ),
              IconButton(
                tooltip: 'Copy to clipboard',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: code.isEmpty ? null : onCopy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _Steps(),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: rotating ? null : onRotate,
            icon: rotating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cached, size: 16),
            label: Text(rotating ? 'Rotating…' : 'Rotate code'),
          ),
        ),
      ],
    );
  }

  static String _maskCode(String code) {
    if (code.isEmpty) return '';
    final parts = code.split('-');
    if (parts.length < 2) {
      if (code.length <= 4) return '•' * code.length;
      return '${'•' * (code.length - 2)}${code.substring(code.length - 2)}';
    }
    final buffer = StringBuffer(parts.first);
    for (var i = 1; i < parts.length; i++) {
      final seg = parts[i];
      buffer.write('-');
      if (i == parts.length - 1 && seg.length > 2) {
        buffer.write('•' * (seg.length - 2));
        buffer.write(seg.substring(seg.length - 2));
      } else {
        buffer.write('•' * seg.length);
      }
    }
    return buffer.toString();
  }
}

// ---------------------------------------------------------------------

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Install the NetworkWise endpoint build on the new Windows PC.',
      'Launch the app — it will stop at the first-run enrollment screen.',
      'Paste the code above and press Continue.',
      'The PC appears in this Devices list within a few seconds.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: const BoxDecoration(
                    color: AppColors.infoBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not load the enrollment code.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
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
          const SizedBox(height: 10),
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
