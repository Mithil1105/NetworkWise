import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../core/models/antivirus_product.dart';
import '../../../../core/models/security_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/info_row.dart';
import '../../../../shared/widgets/section_card.dart';
import '../license_override_dialog.dart';

/// Security tab on the Device Detail screen.
///
/// Renders the full multi-AV inventory discovered by the Windows probe
/// (Defender + Kaspersky / Quick Heal / Bitdefender / Norton / McAfee
/// etc.) alongside the legacy firewall / activation / BitLocker cards.
/// Each AV engine carries its own license-expiry chip with urgency
/// colouring (red <7d, amber <30d, green otherwise, neutral if unknown)
/// and an admin-only "Override license" action that opens a date picker
/// keyed to the engine's display name.
class SecurityInfoTab extends StatelessWidget {
  final SecurityStatus security;
  final String deviceId;

  const SecurityInfoTab({
    super.key,
    required this.security,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    final products = security.antivirusProducts;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: products.isEmpty
                ? 'Antivirus'
                : 'Antivirus (${products.length} engine'
                    '${products.length == 1 ? '' : 's'} detected)',
            subtitle: products.isEmpty
                ? security.antivirusName
                : 'Discovered via Windows Security Center',
            trailing: _StatusPill(
              ok: security.antivirusEnabled && security.antivirusUpToDate,
              okLabel: 'Protected',
              badLabel: 'Action required',
            ),
            child: products.isEmpty
                ? _LegacyAntivirusBlock(security: security)
                : _AntivirusInventory(
                    deviceId: deviceId,
                    products: products,
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Windows Firewall',
            subtitle: 'Profile-level enforcement',
            trailing: _StatusPill(
              ok: security.firewallAllOn,
              okLabel: 'All profiles on',
              badLabel: 'One or more off',
            ),
            child: InfoGrid(
              rows: [
                InfoRow(
                  label: 'Domain profile',
                  value: security.firewallDomain.name.toUpperCase(),
                  trailing:
                      _Dot(ok: security.firewallDomain == FirewallState.enabled),
                ),
                InfoRow(
                  label: 'Private profile',
                  value: security.firewallPrivate.name.toUpperCase(),
                  trailing:
                      _Dot(ok: security.firewallPrivate == FirewallState.enabled),
                ),
                InfoRow(
                  label: 'Public profile',
                  value: security.firewallPublic.name.toUpperCase(),
                  trailing:
                      _Dot(ok: security.firewallPublic == FirewallState.enabled),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Platform',
            subtitle: 'Activation, encryption and updates',
            child: InfoGrid(
              rows: [
                InfoRow(
                  label: 'Windows activated',
                  value: security.windowsActivated
                      ? 'Activated'
                      : 'Not activated',
                  trailing: _Dot(ok: security.windowsActivated),
                ),
                InfoRow(
                  label: 'BitLocker',
                  value: security.bitLockerEnabled ? 'Enabled' : 'Disabled',
                  trailing: _Dot(ok: security.bitLockerEnabled),
                ),
                InfoRow(
                  label: 'Last update check',
                  value: security.lastUpdateCheck == null
                      ? '—'
                      : Formatters.relative(security.lastUpdateCheck!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-AV inventory block (Phase 18).
// ---------------------------------------------------------------------------

class _AntivirusInventory extends StatelessWidget {
  const _AntivirusInventory({
    required this.deviceId,
    required this.products,
  });

  final String deviceId;
  final List<AntivirusProduct> products;

  @override
  Widget build(BuildContext context) {
    // Primary engine first, then enabled, then the rest. Keeps the
    // "active defender" at the top so the admin's eye lands on the
    // engine actually doing the work.
    final sorted = [...products]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        if (a.isEnabled != b.isEnabled) return a.isEnabled ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _AntivirusProductRow(
            deviceId: deviceId,
            product: sorted[i],
          ),
          if (i < sorted.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: AppColors.divider),
            ),
        ],
      ],
    );
  }
}

class _AntivirusProductRow extends StatelessWidget {
  const _AntivirusProductRow({
    required this.deviceId,
    required this.product,
  });

  final String deviceId;
  final AntivirusProduct product;

  @override
  Widget build(BuildContext context) {
    final days = product.daysUntilExpiry();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.isPrimary) ...[
                          const SizedBox(width: 8),
                          const _MiniBadge(
                            label: 'PRIMARY',
                            color: AppColors.info,
                            bg: AppColors.infoBg,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          icon: product.isEnabled
                              ? Icons.verified_user_outlined
                              : Icons.block,
                          label: product.isEnabled ? 'Enabled' : 'Disabled',
                          ok: product.isEnabled,
                        ),
                        _MiniChip(
                          icon: product.isUpToDate
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          label: product.isUpToDate
                              ? 'Up-to-date'
                              : 'Out of date',
                          ok: product.isUpToDate,
                        ),
                        _MiniChip(
                          icon: product.realTimeProtection
                              ? Icons.shield_outlined
                              : Icons.shield_moon_outlined,
                          label: product.realTimeProtection
                              ? 'Real-time on'
                              : 'Real-time off',
                          ok: product.realTimeProtection,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LicenseChip(product: product),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                  label: 'Last scan',
                  value: product.lastScanAt == null
                      ? '—'
                      : Formatters.relative(product.lastScanAt!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InfoRow(
                  label: 'License expires',
                  value: product.licenseExpiresAt == null
                      ? '— (not reported by vendor)'
                      : _formatDate(product.licenseExpiresAt!) +
                          (days == null
                              ? ''
                              : ' (${_daysLabel(days)})'),
                ),
              ),
            ],
          ),
          // Phase 23 — extra rows for the manual override fields. Only
          // render the row when something is filled in so the card
          // stays compact on probe-only devices.
          if (product.definitionsDate != null || product.engineVersion != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: InfoRow(
                      label: 'Definitions / signatures',
                      value: product.definitionsDate == null
                          ? '—'
                          : _formatDate(product.definitionsDate!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoRow(
                      label: 'Engine version',
                      value: product.engineVersion ?? '—',
                    ),
                  ),
                ],
              ),
            ),
          if (product.customStatus != null && product.customStatus!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InfoRow(
                label: 'Custom status',
                value: product.customStatus!,
              ),
            ),
          if (product.note != null && product.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InfoRow(
                label: 'Note',
                value: product.note!,
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Source — ${_sourceLabel(product.licenseSource)}'
                '${product.hasManualOverrides ? ' • manual data on file' : ''}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.neutral,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              if (Env.isAdminRole)
                TextButton.icon(
                  onPressed: () => LicenseOverrideDialog.show(
                    context,
                    deviceId: deviceId,
                    product: product,
                  ),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 14),
                  label: Text(
                    product.hasManualOverrides ||
                            product.licenseSource ==
                                AntivirusLicenseSource.manual
                        ? 'Edit manual data'
                        : 'Add manual data',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _sourceLabel(AntivirusLicenseSource s) => switch (s) {
        AntivirusLicenseSource.wsc => 'Windows Security Center',
        AntivirusLicenseSource.registry => 'Vendor registry',
        AntivirusLicenseSource.manual => 'Admin override',
        AntivirusLicenseSource.unknown => 'Not detected',
      };

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _daysLabel(int days) {
    if (days < 0) return '${-days}d expired';
    if (days == 0) return 'expires today';
    if (days == 1) return '1 day left';
    return '$days days left';
  }
}

class _LicenseChip extends StatelessWidget {
  const _LicenseChip({required this.product});
  final AntivirusProduct product;

  @override
  Widget build(BuildContext context) {
    final days = product.daysUntilExpiry();
    late final Color fg;
    late final Color bg;
    late final IconData icon;
    late final String label;

    if (product.licenseExpiresAt == null) {
      fg = AppColors.neutral;
      bg = AppColors.neutralBg;
      icon = Icons.help_outline;
      label = 'No expiry';
    } else if (days! < 0) {
      fg = AppColors.danger;
      bg = AppColors.dangerBg;
      icon = Icons.error_outline;
      label = 'EXPIRED';
    } else if (days < 7) {
      fg = AppColors.danger;
      bg = AppColors.dangerBg;
      icon = Icons.warning_amber_rounded;
      label = '$days d left';
    } else if (days < 30) {
      fg = AppColors.warning;
      bg = AppColors.warningBg;
      icon = Icons.schedule_outlined;
      label = '$days d left';
    } else {
      fg = AppColors.success;
      bg = AppColors.successBg;
      icon = Icons.verified_outlined;
      label = '$days d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.neutral;
    final bg = ok ? AppColors.successBg : AppColors.neutralBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy single-AV fallback (pre-Phase-18 snapshots without a multi-AV list).
// ---------------------------------------------------------------------------

class _LegacyAntivirusBlock extends StatelessWidget {
  const _LegacyAntivirusBlock({required this.security});
  final SecurityStatus security;

  @override
  Widget build(BuildContext context) {
    return InfoGrid(
      rows: [
        InfoRow(
          label: 'Engine enabled',
          value: security.antivirusEnabled ? 'Yes' : 'No',
          trailing: _Dot(ok: security.antivirusEnabled),
        ),
        InfoRow(
          label: 'Signatures up-to-date',
          value: security.antivirusUpToDate ? 'Yes' : 'No',
          trailing: _Dot(ok: security.antivirusUpToDate),
        ),
        InfoRow(
          label: 'Real-time protection',
          value: security.realTimeProtection ? 'On' : 'Off',
          trailing: _Dot(ok: security.realTimeProtection),
        ),
        InfoRow(
          label: 'Last scan',
          value: security.lastScanAt == null
              ? '—'
              : Formatters.relative(security.lastScanAt!),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool ok;
  final String okLabel;
  final String badLabel;
  const _StatusPill({
    required this.ok,
    required this.okLabel,
    required this.badLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;
    final bg = ok ? AppColors.successBg : AppColors.dangerBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.verified : Icons.error_outline,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            ok ? okLabel : badLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool ok;
  const _Dot({required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
