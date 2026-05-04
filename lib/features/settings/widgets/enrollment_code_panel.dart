import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/organization_provider.dart';
import '../../../core/admin/organization_summary.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_section.dart';

/// Admin-only panel that surfaces the org's rolling enrollment code and
/// lets operators rotate it. Endpoint builds never render this — the
/// parent Settings screen filters by [Env.isAdminRole].
///
/// The code is the single secret a new Windows PC enters on first
/// launch; rotating it invalidates any codes shared out-of-band.
class EnrollmentCodePanel extends ConsumerStatefulWidget {
  const EnrollmentCodePanel({super.key});

  @override
  ConsumerState<EnrollmentCodePanel> createState() =>
      _EnrollmentCodePanelState();
}

class _EnrollmentCodePanelState extends ConsumerState<EnrollmentCodePanel> {
  bool _reveal = false;
  bool _rotating = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(organizationSummaryProvider);

    return SettingsSection(
      title: 'Device enrollment',
      subtitle:
          'Share this code with any new Windows PC so it can join your '
          'organisation. Rotate it immediately if it leaks.',
      icon: Icons.vpn_key_outlined,
      children: [
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () => ref.read(organizationSummaryProvider.notifier)
                .refresh(),
          ),
          data: (summary) {
            if (summary == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Sign in as an admin to view the enrollment code.',
                  style: TextStyle(color: AppColors.neutral),
                ),
              );
            }
            return _Content(
              summary: summary,
              reveal: _reveal,
              rotating: _rotating,
              onToggleReveal: () => setState(() => _reveal = !_reveal),
              onCopy: () => _copy(context, summary.enrollmentCode),
              onRotate: () => _rotate(context),
              onRefresh: () =>
                  ref.read(organizationSummaryProvider.notifier).refresh(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String? code) async {
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

  Future<void> _rotate(BuildContext context) async {
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

class _Content extends StatelessWidget {
  const _Content({
    required this.summary,
    required this.reveal,
    required this.rotating,
    required this.onToggleReveal,
    required this.onCopy,
    required this.onRotate,
    required this.onRefresh,
  });

  final OrganizationSummary summary;
  final bool reveal;
  final bool rotating;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;
  final VoidCallback onRotate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final code = summary.enrollmentCode ?? '';
    final rotated = summary.enrollmentCodeRotatedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CodeDisplay(
            code: code,
            reveal: reveal,
            onToggleReveal: onToggleReveal,
            onCopy: onCopy,
          ),
          const SizedBox(height: 10),
          _Meta(organisationName: summary.name, rotatedAt: rotated),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: rotating ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
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
              FilledButton.icon(
                onPressed: rotating ? null : onRotate,
                icon: rotating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cached, size: 16),
                label: Text(rotating ? 'Rotating…' : 'Rotate code'),
                style: FilledButton.styleFrom(
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
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------

class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({
    required this.code,
    required this.reveal,
    required this.onToggleReveal,
    required this.onCopy,
  });

  final String code;
  final bool reveal;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final masked = _maskCode(code);
    final shown = reveal ? code : masked;

    return Container(
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
              reveal ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
    );
  }

  /// Turns `MSH-7F2K-91QR` into `MSH-••••-••QR` so the code isn't
  /// visible to a shoulder-surfer but the operator can confirm the
  /// prefix and last two characters at a glance.
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

class _Meta extends StatelessWidget {
  const _Meta({required this.organisationName, required this.rotatedAt});

  final String organisationName;
  final DateTime? rotatedAt;

  @override
  Widget build(BuildContext context) {
    final rotatedLabel = rotatedAt == null
        ? 'Never rotated'
        : 'Rotated ${_relative(rotatedAt!)}';

    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 11.5, color: AppColors.neutral),
      child: Row(
        children: [
          const Icon(
            Icons.business_outlined,
            size: 14,
            color: AppColors.neutral,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              organisationName.isEmpty
                  ? 'Your organisation'
                  : organisationName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.schedule_outlined,
            size: 14,
            color: AppColors.neutral,
          ),
          const SizedBox(width: 6),
          Text(rotatedLabel),
        ],
      ),
    );
  }

  static String _relative(DateTime ts) {
    final now = DateTime.now().toUtc();
    final stamp = ts.toUtc();
    final d = now.difference(stamp);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    final months = (d.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (d.inDays / 365).floor();
    return '${years}y ago';
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              const Text(
                'Could not load the enrollment code.',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
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
