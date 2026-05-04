import '../../../core/models/device.dart';
import '../../../core/models/security_status.dart';
import '../../devices/data/mock_device_detail.dart';
import '../../devices/data/mock_devices.dart';

/// Aggregate security posture for a single device — already reduced
/// into display-friendly booleans.
class DeviceCompliance {
  final Device device;
  final SecurityStatus security;

  const DeviceCompliance({
    required this.device,
    required this.security,
  });

  bool get avOk =>
      security.antivirusEnabled &&
      security.antivirusUpToDate &&
      security.realTimeProtection;

  bool get firewallOk => security.firewallAllOn;

  bool get activationOk => security.windowsActivated;

  bool get bitLockerOk => security.bitLockerEnabled;

  /// 0 → compliant, 1/2 → at risk, 3+ → critical.
  int get failureCount {
    var n = 0;
    if (!avOk) n++;
    if (!firewallOk) n++;
    if (!activationOk) n++;
    if (!bitLockerOk) n++;
    return n;
  }

  ComplianceLevel get level {
    // BitLocker-only failure shouldn't tip a device into "critical".
    final serious = (avOk ? 0 : 1) + (firewallOk ? 0 : 1) + (activationOk ? 0 : 1);
    if (serious >= 2) return ComplianceLevel.critical;
    if (serious == 1 || !bitLockerOk) return ComplianceLevel.atRisk;
    return ComplianceLevel.compliant;
  }
}

enum ComplianceLevel { compliant, atRisk, critical }

/// Fleet-wide roll-up used by the Security screen.
class FleetSecuritySummary {
  final List<DeviceCompliance> devices;

  const FleetSecuritySummary(this.devices);

  factory FleetSecuritySummary.build() {
    final list = [
      for (final d in MockDevices.all)
        DeviceCompliance(
          device: d,
          security: MockDeviceDetail.forDeviceId(d.id).security,
        ),
    ];
    return FleetSecuritySummary(list);
  }

  int get total => devices.length;

  int get compliant =>
      devices.where((d) => d.level == ComplianceLevel.compliant).length;
  int get atRisk =>
      devices.where((d) => d.level == ComplianceLevel.atRisk).length;
  int get critical =>
      devices.where((d) => d.level == ComplianceLevel.critical).length;

  /// 0-100 — weighted mean of the four controls.
  double get score {
    if (devices.isEmpty) return 100;
    final avW = 0.40, fwW = 0.30, actW = 0.20, blW = 0.10;
    var sum = 0.0;
    for (final d in devices) {
      sum += (d.avOk ? avW : 0) +
          (d.firewallOk ? fwW : 0) +
          (d.activationOk ? actW : 0) +
          (d.bitLockerOk ? blW : 0);
    }
    return (sum / devices.length) * 100.0;
  }

  // --- Antivirus ---
  int get avEnabled => devices.where((d) => d.security.antivirusEnabled).length;
  int get avUpToDate =>
      devices.where((d) => d.security.antivirusUpToDate).length;
  int get avRealTime =>
      devices.where((d) => d.security.realTimeProtection).length;
  int get avScannedRecently => devices
      .where((d) =>
          d.security.lastScanAt != null &&
          DateTime.now().difference(d.security.lastScanAt!).inHours < 24)
      .length;

  // --- Firewall (profile-level) ---
  int get fwDomain => devices
      .where((d) => d.security.firewallDomain == FirewallState.enabled)
      .length;
  int get fwPrivate => devices
      .where((d) => d.security.firewallPrivate == FirewallState.enabled)
      .length;
  int get fwPublic => devices
      .where((d) => d.security.firewallPublic == FirewallState.enabled)
      .length;
  int get fwAllThree => devices.where((d) => d.security.firewallAllOn).length;

  // --- Platform ---
  int get activated =>
      devices.where((d) => d.security.windowsActivated).length;
  int get bitLocker =>
      devices.where((d) => d.security.bitLockerEnabled).length;
  int get updatedRecently => devices
      .where((d) =>
          d.security.lastUpdateCheck != null &&
          DateTime.now().difference(d.security.lastUpdateCheck!).inDays < 7)
      .length;
}
