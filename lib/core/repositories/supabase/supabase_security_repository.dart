import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/antivirus_product.dart';
import '../../models/security_status.dart';
import '../i_security_repository.dart';

/// Supabase-backed implementation of [ISecurityRepository].
///
/// The table `security_status` is append-only — callers read the most
/// recent row per device and append new ones via `report-snapshot`.
class SupabaseSecurityRepository implements ISecurityRepository {
  SupabaseSecurityRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SecurityStatus?> latestForDevice(String deviceId) async {
    final row = await _client
        .from('security_status')
        .select()
        .eq('device_id', deviceId)
        .order('observed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final products = await _avProductsForDevice(deviceId);
    final overrides = await _overridesForDevice(deviceId);
    return _mapRow(row).copyWith(
      antivirusProducts: _mergeOverrides(products, overrides),
    );
  }

  @override
  Future<Map<String, SecurityStatus>> latestForAllDevices() async {
    // For a modest fleet (<5000 devices) it is cheaper and simpler to
    // pull the whole table and fold in memory than to coalesce on the
    // server. A dedicated RPC can replace this when the fleet grows.
    final rows = await _client
        .from('security_status')
        .select()
        .order('observed_at', ascending: false);
    final latest = <String, SecurityStatus>{};
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final deviceId = row['device_id'] as String;
      latest.putIfAbsent(deviceId, () => _mapRow(row));
    }

    // Pull the full AV inventory in a single round-trip and attach it
    // to the corresponding device's SecurityStatus. Same pattern for
    // the admin overrides so the fleet list can flag license expiry
    // without the detail screen having to fetch anything.
    final avRows = await _client.from('security_antivirus_products').select();
    final byDevice = <String, List<AntivirusProduct>>{};
    for (final raw in avRows) {
      final row = raw as Map<String, dynamic>;
      final deviceId = row['device_id'] as String;
      (byDevice[deviceId] ??= <AntivirusProduct>[]).add(_mapAvRow(row));
    }

    final overrideRows =
        await _client.from('security_av_license_overrides').select();
    final overridesByDevice = <String, Map<String, _AvOverride>>{};
    for (final raw in overrideRows) {
      final row = raw as Map<String, dynamic>;
      final deviceId = row['device_id'] as String;
      final name = (row['display_name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      (overridesByDevice[deviceId] ??= <String, _AvOverride>{})[name] =
          _AvOverride.fromRow(row);
    }

    final merged = <String, SecurityStatus>{};
    latest.forEach((deviceId, status) {
      merged[deviceId] = status.copyWith(
        antivirusProducts: _mergeOverrides(
          byDevice[deviceId] ?? const <AntivirusProduct>[],
          overridesByDevice[deviceId] ?? const <String, _AvOverride>{},
        ),
      );
    });
    return merged;
  }

  /// Admin-only: write (or replace) a manual license expiry override
  /// for a given AV on a given device. Keyed by `(device_id,
  /// display_name)` so admins don't need to know the probe's internal
  /// product_id.
  ///
  /// Phase 23 — accepts the extended override fields too. Any field
  /// passed as `null` is left unchanged in the existing row; pass an
  /// explicit empty string to clear a previously-set value.
  @override
  Future<void> setLicenseOverride({
    required String deviceId,
    required String organizationId,
    required String displayName,
    DateTime? expiresAt,
    String? note,
    DateTime? lastScanAt,
    DateTime? definitionsDate,
    String? customStatus,
    String? engineVersion,
  }) async {
    final payload = <String, dynamic>{
      'device_id': deviceId,
      'organization_id': organizationId,
      'display_name': displayName,
      'set_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (expiresAt != null) {
      payload['license_expires_at'] = expiresAt.toUtc().toIso8601String();
    }
    if (note != null) {
      final t = note.trim();
      payload['note'] = t.isEmpty ? null : t;
    }
    if (lastScanAt != null) {
      payload['last_scan_at_override'] =
          lastScanAt.toUtc().toIso8601String();
    }
    if (definitionsDate != null) {
      payload['definitions_date_override'] =
          definitionsDate.toUtc().toIso8601String();
    }
    if (customStatus != null) {
      final t = customStatus.trim();
      payload['custom_status'] = t.isEmpty ? null : t;
    }
    if (engineVersion != null) {
      final t = engineVersion.trim();
      payload['engine_version'] = t.isEmpty ? null : t;
    }
    await _client.from('security_av_license_overrides').upsert(
      payload,
      onConflict: 'device_id,display_name',
    );
  }

  /// Admin-only: drop a previously-set manual override, letting the
  /// probe's own license_expires_at win again.
  @override
  Future<void> clearLicenseOverride({
    required String deviceId,
    required String displayName,
  }) async {
    await _client
        .from('security_av_license_overrides')
        .delete()
        .eq('device_id', deviceId)
        .eq('display_name', displayName);
  }

  Future<List<AntivirusProduct>> _avProductsForDevice(String deviceId) async {
    final rows = await _client
        .from('security_antivirus_products')
        .select()
        .eq('device_id', deviceId);
    return rows
        .map((r) => _mapAvRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, _AvOverride>> _overridesForDevice(String deviceId) async {
    final rows = await _client
        .from('security_av_license_overrides')
        .select()
        .eq('device_id', deviceId);
    final map = <String, _AvOverride>{};
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final name = (row['display_name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      map[name] = _AvOverride.fromRow(row);
    }
    return map;
  }

  List<AntivirusProduct> _mergeOverrides(
    List<AntivirusProduct> products,
    Map<String, _AvOverride> overrides,
  ) {
    if (overrides.isEmpty) return products;
    return products.map((p) {
      final override = overrides[p.displayName];
      if (override == null) return p;
      // Manual override fields layer ON TOP of whatever the probe
      // captured — so a "Manually verified" status note can coexist
      // with a probe-detected lastScanAt, but the manual scan date
      // wins when both are present.
      return p.copyWith(
        licenseExpiresAt: override.licenseExpiresAt ?? p.licenseExpiresAt,
        licenseSource: override.licenseExpiresAt != null
            ? AntivirusLicenseSource.manual
            : p.licenseSource,
        lastScanAt: override.lastScanAt ?? p.lastScanAt,
        definitionsDate: override.definitionsDate,
        engineVersion: override.engineVersion,
        customStatus: override.customStatus,
        note: override.note,
        hasManualOverrides: override.hasAnyOverride,
      );
    }).toList(growable: false);
  }

  AntivirusProduct _mapAvRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    final sourceRaw = row['license_source']?.toString();
    final source = AntivirusLicenseSource.values.firstWhere(
      (e) => e.name == sourceRaw,
      orElse: () => AntivirusLicenseSource.unknown,
    );
    return AntivirusProduct(
      displayName: (row['display_name'] as String?) ?? 'Unknown',
      productId: (row['product_id'] as String?) ?? '',
      isPrimary: (row['is_primary'] as bool?) ?? false,
      isEnabled: (row['is_enabled'] as bool?) ?? false,
      isUpToDate: (row['is_up_to_date'] as bool?) ?? false,
      realTimeProtection: (row['real_time_protection'] as bool?) ?? false,
      lastScanAt: parse(row['last_scan_at']),
      licenseExpiresAt: parse(row['license_expires_at']),
      licenseSource: source,
    );
  }

  @override
  Future<void> appendSnapshot({
    required String deviceId,
    required String registrationSecret,
    required SecurityStatus snapshot,
  }) async {
    // Shipped with empty adapters — the higher-level
    // `submitSnapshot` path bundles both in a single Edge Function call.
    final body = <String, dynamic>{
      'device_id': deviceId,
      'registration_secret': registrationSecret,
      'adapters': const <dynamic>[],
      'security': _toSnapshotJson(snapshot),
    };
    final response =
        await _client.functions.invoke('report-snapshot', body: body);
    if (response.status != null && response.status! >= 400) {
      throw StateError(
        'report-snapshot (security) failed (${response.status}): ${response.data}',
      );
    }
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  SecurityStatus _mapRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.parse(v) : null;
    FirewallState fw(Object? v) {
      switch (v) {
        case 'enabled':
          return FirewallState.enabled;
        case 'disabled':
          return FirewallState.disabled;
        default:
          return FirewallState.unknown;
      }
    }

    return SecurityStatus(
      deviceId: row['device_id'] as String,
      antivirusName: (row['antivirus_name'] as String?) ?? 'Unknown',
      antivirusEnabled: (row['antivirus_enabled'] as bool?) ?? false,
      antivirusUpToDate: (row['antivirus_up_to_date'] as bool?) ?? false,
      realTimeProtection: (row['real_time_protection'] as bool?) ?? false,
      lastScanAt: parse(row['last_scan_at']),
      firewallDomain: fw(row['firewall_domain']),
      firewallPrivate: fw(row['firewall_private']),
      firewallPublic: fw(row['firewall_public']),
      windowsActivated: (row['windows_activated'] as bool?) ?? false,
      bitLockerEnabled: (row['bitlocker_enabled'] as bool?) ?? false,
      lastUpdateCheck: parse(row['last_update_check']),
    );
  }

  Map<String, dynamic> _toSnapshotJson(SecurityStatus s) {
    String fw(FirewallState v) => switch (v) {
          FirewallState.enabled => 'enabled',
          FirewallState.disabled => 'disabled',
          FirewallState.unknown => 'unknown',
        };
    return <String, dynamic>{
      'antivirus_name': s.antivirusName,
      'antivirus_enabled': s.antivirusEnabled,
      'antivirus_up_to_date': s.antivirusUpToDate,
      'real_time_protection': s.realTimeProtection,
      'last_scan_at': s.lastScanAt?.toIso8601String(),
      'firewall_domain': fw(s.firewallDomain),
      'firewall_private': fw(s.firewallPrivate),
      'firewall_public': fw(s.firewallPublic),
      'windows_activated': s.windowsActivated,
      'bitlocker_enabled': s.bitLockerEnabled,
      'last_update_check': s.lastUpdateCheck?.toIso8601String(),
      'antivirus_products': s.antivirusProducts
          .map((p) => <String, dynamic>{
                'display_name': p.displayName,
                'product_id': p.productId,
                'is_primary': p.isPrimary,
                'is_enabled': p.isEnabled,
                'is_up_to_date': p.isUpToDate,
                'real_time_protection': p.realTimeProtection,
                'last_scan_at': p.lastScanAt?.toIso8601String(),
                'license_expires_at': p.licenseExpiresAt?.toIso8601String(),
                'license_source': p.licenseSource.name,
              })
          .toList(growable: false),
    };
  }
}

/// Parsed shape of a single row from `security_av_license_overrides`.
/// Phase 23 — what used to be a single `Map<String, DateTime>` (license
/// expiry only) is now a richer record carrying every admin-entered
/// field. Keep this private to the repository — UI code never touches
/// it directly, the merge step folds the values into [AntivirusProduct].
class _AvOverride {
  const _AvOverride({
    this.licenseExpiresAt,
    this.lastScanAt,
    this.definitionsDate,
    this.customStatus,
    this.engineVersion,
    this.note,
  });

  final DateTime? licenseExpiresAt;
  final DateTime? lastScanAt;
  final DateTime? definitionsDate;
  final String? customStatus;
  final String? engineVersion;
  final String? note;

  bool get hasAnyOverride =>
      licenseExpiresAt != null ||
      lastScanAt != null ||
      definitionsDate != null ||
      (customStatus != null && customStatus!.isNotEmpty) ||
      (engineVersion != null && engineVersion!.isNotEmpty) ||
      (note != null && note!.isNotEmpty);

  static DateTime? _parse(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  static String? _parseString(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  factory _AvOverride.fromRow(Map<String, dynamic> row) {
    return _AvOverride(
      licenseExpiresAt: _parse(row['license_expires_at']),
      lastScanAt: _parse(row['last_scan_at_override']),
      definitionsDate: _parse(row['definitions_date_override']),
      customStatus: _parseString(row['custom_status']),
      engineVersion: _parseString(row['engine_version']),
      note: _parseString(row['note']),
    );
  }
}
