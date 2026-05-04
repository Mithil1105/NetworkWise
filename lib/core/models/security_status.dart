import 'package:flutter/foundation.dart';

import 'antivirus_product.dart';

enum FirewallState { enabled, disabled, unknown }

FirewallState _parseFirewall(Object? v) {
  return FirewallState.values.firstWhere(
    (e) => e.name == v,
    orElse: () => FirewallState.unknown,
  );
}

/// Security posture snapshot for a device.
@immutable
class SecurityStatus {
  final String deviceId;

  // Antivirus — the legacy single-AV fields below describe the PRIMARY
  // AV (the one WSC is relying on) and are kept so every existing
  // screen keeps painting. The full multi-AV inventory lives on
  // [antivirusProducts].
  final String antivirusName;
  final bool antivirusEnabled;
  final bool antivirusUpToDate;
  final bool realTimeProtection;
  final DateTime? lastScanAt;

  /// Every AV product the probe discovered on this endpoint — Defender
  /// plus any third-party engines (Kaspersky, Quick Heal, Bitdefender,
  /// Norton, McAfee, etc.) registered with Windows Security Center.
  /// Includes per-product license expiry when the vendor surfaces it.
  final List<AntivirusProduct> antivirusProducts;

  // Firewall (per-profile on Windows)
  final FirewallState firewallDomain;
  final FirewallState firewallPrivate;
  final FirewallState firewallPublic;

  // Platform
  final bool windowsActivated;
  final bool bitLockerEnabled;
  final DateTime? lastUpdateCheck;

  const SecurityStatus({
    required this.deviceId,
    required this.antivirusName,
    required this.antivirusEnabled,
    required this.antivirusUpToDate,
    required this.realTimeProtection,
    required this.lastScanAt,
    required this.firewallDomain,
    required this.firewallPrivate,
    required this.firewallPublic,
    required this.windowsActivated,
    required this.bitLockerEnabled,
    required this.lastUpdateCheck,
    this.antivirusProducts = const <AntivirusProduct>[],
  });

  /// Convenience: all three firewall profiles on.
  bool get firewallAllOn =>
      firewallDomain == FirewallState.enabled &&
      firewallPrivate == FirewallState.enabled &&
      firewallPublic == FirewallState.enabled;

  SecurityStatus copyWith({
    String? deviceId,
    String? antivirusName,
    bool? antivirusEnabled,
    bool? antivirusUpToDate,
    bool? realTimeProtection,
    DateTime? lastScanAt,
    FirewallState? firewallDomain,
    FirewallState? firewallPrivate,
    FirewallState? firewallPublic,
    bool? windowsActivated,
    bool? bitLockerEnabled,
    DateTime? lastUpdateCheck,
    List<AntivirusProduct>? antivirusProducts,
  }) {
    return SecurityStatus(
      deviceId: deviceId ?? this.deviceId,
      antivirusName: antivirusName ?? this.antivirusName,
      antivirusEnabled: antivirusEnabled ?? this.antivirusEnabled,
      antivirusUpToDate: antivirusUpToDate ?? this.antivirusUpToDate,
      realTimeProtection: realTimeProtection ?? this.realTimeProtection,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      firewallDomain: firewallDomain ?? this.firewallDomain,
      firewallPrivate: firewallPrivate ?? this.firewallPrivate,
      firewallPublic: firewallPublic ?? this.firewallPublic,
      windowsActivated: windowsActivated ?? this.windowsActivated,
      bitLockerEnabled: bitLockerEnabled ?? this.bitLockerEnabled,
      lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
      antivirusProducts: antivirusProducts ?? this.antivirusProducts,
    );
  }

  factory SecurityStatus.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['antivirusProducts'] ?? json['antivirus_products'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map>()
            .map((m) => AntivirusProduct.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList(growable: false)
        : const <AntivirusProduct>[];
    return SecurityStatus(
      deviceId: json['deviceId'] as String,
      antivirusName: json['antivirusName'] as String? ?? 'Unknown',
      antivirusEnabled: json['antivirusEnabled'] as bool? ?? false,
      antivirusUpToDate: json['antivirusUpToDate'] as bool? ?? false,
      realTimeProtection: json['realTimeProtection'] as bool? ?? false,
      lastScanAt: json['lastScanAt'] == null
          ? null
          : DateTime.parse(json['lastScanAt'] as String),
      firewallDomain: _parseFirewall(json['firewallDomain']),
      firewallPrivate: _parseFirewall(json['firewallPrivate']),
      firewallPublic: _parseFirewall(json['firewallPublic']),
      windowsActivated: json['windowsActivated'] as bool? ?? false,
      bitLockerEnabled: json['bitLockerEnabled'] as bool? ?? false,
      lastUpdateCheck: json['lastUpdateCheck'] == null
          ? null
          : DateTime.parse(json['lastUpdateCheck'] as String),
      antivirusProducts: products,
    );
  }

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'antivirusName': antivirusName,
        'antivirusEnabled': antivirusEnabled,
        'antivirusUpToDate': antivirusUpToDate,
        'realTimeProtection': realTimeProtection,
        'lastScanAt': lastScanAt?.toIso8601String(),
        'firewallDomain': firewallDomain.name,
        'firewallPrivate': firewallPrivate.name,
        'firewallPublic': firewallPublic.name,
        'windowsActivated': windowsActivated,
        'bitLockerEnabled': bitLockerEnabled,
        'lastUpdateCheck': lastUpdateCheck?.toIso8601String(),
        'antivirusProducts':
            antivirusProducts.map((p) => p.toJson()).toList(growable: false),
      };

  factory SecurityStatus.mock({String deviceId = 'dev-001'}) => SecurityStatus(
        deviceId: deviceId,
        antivirusName: 'Windows Defender',
        antivirusEnabled: true,
        antivirusUpToDate: true,
        realTimeProtection: true,
        lastScanAt: DateTime.now().subtract(const Duration(hours: 6)),
        firewallDomain: FirewallState.enabled,
        firewallPrivate: FirewallState.enabled,
        firewallPublic: FirewallState.enabled,
        windowsActivated: true,
        bitLockerEnabled: false,
        lastUpdateCheck: DateTime.now().subtract(const Duration(days: 1)),
      );
}
