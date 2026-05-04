import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/admin/organization_provider.dart';
import '../../../core/models/antivirus_product.dart';
import '../../../core/repositories/supabase/supabase_repositories_providers.dart';
import '../../../core/services/data_service_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Phase 18 — admin-only dialog for pinning a manual license expiry
/// date against a specific AV engine on a specific device.
///
/// Phase 23 — extended into a comprehensive "Manual AV Data" override:
/// admins can additionally enter last scan date, definitions / signature
/// date, engine version, and a custom status string. Useful for Quick
/// Heal and other SMB AVs where the probe can't reliably reach those
/// fields. Each individual field is optional — leave anything blank to
/// keep what the probe captured.
class LicenseOverrideDialog extends ConsumerStatefulWidget {
  const LicenseOverrideDialog({
    super.key,
    required this.deviceId,
    required this.product,
  });

  final String deviceId;
  final AntivirusProduct product;

  static Future<bool?> show(
    BuildContext context, {
    required String deviceId,
    required AntivirusProduct product,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          LicenseOverrideDialog(deviceId: deviceId, product: product),
    );
  }

  @override
  ConsumerState<LicenseOverrideDialog> createState() =>
      _LicenseOverrideDialogState();
}

class _LicenseOverrideDialogState
    extends ConsumerState<LicenseOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _engineVersion = TextEditingController();
  final TextEditingController _customStatus = TextEditingController();

  DateTime? _expiry;
  DateTime? _lastScan;
  DateTime? _definitions;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _expiry = p.licenseExpiresAt?.toLocal();
    _lastScan = p.lastScanAt?.toLocal();
    _definitions = p.definitionsDate?.toLocal();
    _engineVersion.text = p.engineVersion ?? '';
    _customStatus.text = p.customStatus ?? '';
    _note.text = p.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _engineVersion.dispose();
    _customStatus.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365 * 10));
    final lastDate = now.add(const Duration(days: 365 * 10));
    final seed = initial ?? now;
    return showDatePicker(
      context: context,
      initialDate: seed.isBefore(firstDate)
          ? firstDate
          : (seed.isAfter(lastDate) ? lastDate : seed),
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final hasAny = _expiry != null ||
        _lastScan != null ||
        _definitions != null ||
        _engineVersion.text.trim().isNotEmpty ||
        _customStatus.text.trim().isNotEmpty ||
        _note.text.trim().isNotEmpty;
    if (!hasAny) {
      setState(() => _error =
          'Fill in at least one field — pick a date, type a status, or capture engine details.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final orgSummary = ref.read(organizationSummaryProvider).valueOrNull;
      if (orgSummary == null) {
        throw StateError('Organisation not resolved — sign in again.');
      }
      final repo = ref.read(supabaseSecurityRepositoryProvider);
      await repo.setLicenseOverride(
        deviceId: widget.deviceId,
        organizationId: orgSummary.id,
        displayName: widget.product.displayName,
        expiresAt: _expiry == null
            ? null
            : DateTime.utc(_expiry!.year, _expiry!.month, _expiry!.day,
                23, 59, 59),
        lastScanAt: _lastScan == null
            ? null
            : DateTime.utc(_lastScan!.year, _lastScan!.month, _lastScan!.day,
                12, 0, 0),
        definitionsDate: _definitions == null
            ? null
            : DateTime.utc(_definitions!.year, _definitions!.month,
                _definitions!.day, 12, 0, 0),
        engineVersion:
            _engineVersion.text.trim().isEmpty ? null : _engineVersion.text,
        customStatus:
            _customStatus.text.trim().isEmpty ? null : _customStatus.text,
        note: _note.text.trim().isEmpty ? null : _note.text,
      );
      await ref.read(dataServiceProvider).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(supabaseSecurityRepositoryProvider);
      await repo.clearLicenseOverride(
        deviceId: widget.deviceId,
        displayName: widget.product.displayName,
      );
      await ref.read(dataServiceProvider).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManual =
        widget.product.licenseSource == AntivirusLicenseSource.manual ||
            widget.product.hasManualOverrides;
    return AlertDialog(
      title: Text('Manual AV data — ${widget.product.displayName}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Fill in whatever the probe could not capture. Manual values '
                  'always win over the probe — clear the override later to '
                  'fall back on auto-detection.',
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.neutral),
                ),
                const SizedBox(height: 14),
                _DateRow(
                  label: 'License expiry',
                  hint: 'When does the AV subscription end?',
                  value: _expiry,
                  busy: _busy,
                  onPick: () async {
                    final d = await _pickDate(_expiry ??
                        DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => _expiry = d);
                  },
                  onClear: _expiry == null
                      ? null
                      : () => setState(() => _expiry = null),
                ),
                const SizedBox(height: 10),
                _DateRow(
                  label: 'Last scan',
                  hint: 'Date of the most recent full / quick scan.',
                  value: _lastScan,
                  busy: _busy,
                  onPick: () async {
                    final d = await _pickDate(_lastScan ?? DateTime.now());
                    if (d != null) setState(() => _lastScan = d);
                  },
                  onClear: _lastScan == null
                      ? null
                      : () => setState(() => _lastScan = null),
                ),
                const SizedBox(height: 10),
                _DateRow(
                  label: 'Definitions / signatures',
                  hint: 'Date of the latest virus definitions update.',
                  value: _definitions,
                  busy: _busy,
                  onPick: () async {
                    final d = await _pickDate(_definitions ?? DateTime.now());
                    if (d != null) setState(() => _definitions = d);
                  },
                  onClear: _definitions == null
                      ? null
                      : () => setState(() => _definitions = null),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _engineVersion,
                  enabled: !_busy,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Engine / product version (optional)',
                    hintText: 'e.g. Quick Heal Total Security 23.00',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _customStatus,
                  enabled: !_busy,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Custom status (optional)',
                    hintText: 'e.g. Verified manually 2026-04-15',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  controller: _note,
                  enabled: !_busy,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'PO #4417 — renewal queued by Finance',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (isManual)
          TextButton(
            onPressed: _busy ? null : _clear,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear all overrides'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save override'),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String hint;
  final DateTime? value;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = value == null
        ? '— pick a date —'
        : '${value!.year.toString().padLeft(4, '0')}-'
            '${value!.month.toString().padLeft(2, '0')}-'
            '${value!.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: value == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close, size: 16),
              onPressed: busy ? null : onClear,
            ),
          OutlinedButton.icon(
            onPressed: busy ? null : onPick,
            icon: const Icon(Icons.event_outlined, size: 16),
            label: Text(value == null ? 'Pick' : 'Change'),
          ),
        ],
      ),
    );
  }
}
