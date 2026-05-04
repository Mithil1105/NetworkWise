import 'package:flutter/foundation.dart';

/// Where the license expiry for an AV product came from.
///
///   * [wsc]       — reported directly by Windows Security Center (rare,
///                   most WSC providers just expose status, not expiry).
///   * [registry]  — read from the vendor's own registry keys (Kaspersky,
///                   Quick Heal, Bitdefender, Norton, McAfee all stash a
///                   `LicenseExpiry`/`ExpirationDate` string under HKLM).
///   * [manual]    — admin typed the date into the Security tab to
///                   override / supplement whatever the probe found.
///   * [unknown]   — no source could resolve a date; UI should prompt
///                   the admin to enter one manually.
enum AntivirusLicenseSource { wsc, registry, manual, unknown }

AntivirusLicenseSource _parseLicenseSource(Object? v) {
  return AntivirusLicenseSource.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AntivirusLicenseSource.unknown,
  );
}

/// A single antivirus product discovered on the endpoint.
///
/// Multi-AV is a real-world concern on business machines — Defender can
/// sit alongside Kaspersky / Quick Heal / Bitdefender in passive mode,
/// and the dashboard needs to track each product's protection state AND
/// license expiry independently. This model is per-product; the parent
/// `SecurityStatus` carries a `List<AntivirusProduct>` plus the
/// aggregated firewall / activation / BitLocker fields.
@immutable
class AntivirusProduct {
  /// Human-readable name — e.g. "Windows Defender", "Kaspersky Endpoint
  /// Security 11.10", "Quick Heal Total Security".
  final String displayName;

  /// Opaque identifier the probe can use to dedupe on the next sample.
  /// On Windows this is the WSC `instanceGuid`; on other platforms it
  /// may be a registry key path or a vendor product id.
  final String productId;

  /// Is this the primary AV the OS is relying on? In WSC there is
  /// always exactly one "active" provider; the rest sit in passive
  /// mode. For non-Windows this may just mark the first found.
  final bool isPrimary;

  /// Real-time protection enabled (SCAN_ON_ACCESS in WSC bitmask).
  final bool isEnabled;

  /// Definitions / signatures up to date.
  final bool isUpToDate;

  /// Continuous file-system scanning running. Often overlaps with
  /// [isEnabled] but is tracked separately because some products offer
  /// manual-only mode.
  final bool realTimeProtection;

  /// Timestamp of the last full scan, if the vendor surfaces it.
  final DateTime? lastScanAt;

  /// License expiry date detected by the probe (may be `null` when the
  /// vendor doesn't expose it — Windows Defender is free so there is
  /// none, and some SMB AVs hide expiry behind a cloud portal).
  final DateTime? licenseExpiresAt;

  /// Where [licenseExpiresAt] originally came from. Used by the UI so
  /// the admin can see whether a date was auto-detected or manually
  /// entered, and can re-run detection to override a manual entry.
  final AntivirusLicenseSource licenseSource;

  /// Phase 23 — extended manual-override fields. The probe leaves these
  /// null and the merge step in the security repository fills them
  /// from `security_av_license_overrides` when the admin has typed
  /// values in. Useful for vendors (Quick Heal in particular) that
  /// hide last-scan / definitions / engine version behind a cloud
  /// portal the probe can't reach.
  final DateTime? definitionsDate;
  final String? engineVersion;
  final String? customStatus;
  final String? note;

  /// Whether last scan / definitions / engine were filled in manually
  /// (admin override) rather than read live from the probe.
  final bool hasManualOverrides;

  const AntivirusProduct({
    required this.displayName,
    required this.productId,
    required this.isPrimary,
    required this.isEnabled,
    required this.isUpToDate,
    required this.realTimeProtection,
    required this.lastScanAt,
    required this.licenseExpiresAt,
    required this.licenseSource,
    this.definitionsDate,
    this.engineVersion,
    this.customStatus,
    this.note,
    this.hasManualOverrides = false,
  });

  /// Days between `now` and [licenseExpiresAt]. Returns `null` when no
  /// date is known. Negative values mean the license has already lapsed.
  int? daysUntilExpiry({DateTime? now}) {
    final expiry = licenseExpiresAt;
    if (expiry == null) return null;
    final ref = now ?? DateTime.now();
    return expiry.difference(ref).inDays;
  }

  AntivirusProduct copyWith({
    String? displayName,
    String? productId,
    bool? isPrimary,
    bool? isEnabled,
    bool? isUpToDate,
    bool? realTimeProtection,
    DateTime? lastScanAt,
    DateTime? licenseExpiresAt,
    AntivirusLicenseSource? licenseSource,
    DateTime? definitionsDate,
    String? engineVersion,
    String? customStatus,
    String? note,
    bool? hasManualOverrides,
  }) {
    return AntivirusProduct(
      displayName: displayName ?? this.displayName,
      productId: productId ?? this.productId,
      isPrimary: isPrimary ?? this.isPrimary,
      isEnabled: isEnabled ?? this.isEnabled,
      isUpToDate: isUpToDate ?? this.isUpToDate,
      realTimeProtection: realTimeProtection ?? this.realTimeProtection,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      licenseExpiresAt: licenseExpiresAt ?? this.licenseExpiresAt,
      licenseSource: licenseSource ?? this.licenseSource,
      definitionsDate: definitionsDate ?? this.definitionsDate,
      engineVersion: engineVersion ?? this.engineVersion,
      customStatus: customStatus ?? this.customStatus,
      note: note ?? this.note,
      hasManualOverrides: hasManualOverrides ?? this.hasManualOverrides,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'display_name': displayName,
        'product_id': productId,
        'is_primary': isPrimary,
        'is_enabled': isEnabled,
        'is_up_to_date': isUpToDate,
        'real_time_protection': realTimeProtection,
        'last_scan_at': lastScanAt?.toIso8601String(),
        'license_expires_at': licenseExpiresAt?.toIso8601String(),
        'license_source': licenseSource.name,
      };

  factory AntivirusProduct.fromJson(Map<String, dynamic> j) => AntivirusProduct(
        displayName: (j['display_name'] as String?) ??
            (j['displayName'] as String?) ??
            'Unknown',
        productId: (j['product_id'] as String?) ??
            (j['productId'] as String?) ??
            '',
        isPrimary: (j['is_primary'] as bool?) ??
            (j['isPrimary'] as bool?) ??
            false,
        isEnabled: (j['is_enabled'] as bool?) ??
            (j['isEnabled'] as bool?) ??
            false,
        isUpToDate: (j['is_up_to_date'] as bool?) ??
            (j['isUpToDate'] as bool?) ??
            false,
        realTimeProtection: (j['real_time_protection'] as bool?) ??
            (j['realTimeProtection'] as bool?) ??
            false,
        lastScanAt: _parseNullableIso(j['last_scan_at'] ?? j['lastScanAt']),
        licenseExpiresAt:
            _parseNullableIso(j['license_expires_at'] ?? j['licenseExpiresAt']),
        licenseSource: _parseLicenseSource(
          j['license_source'] ?? j['licenseSource'],
        ),
      );

  static DateTime? _parseNullableIso(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
