import '../../../core/models/alert.dart';
import '../../../core/models/network_adapter.dart';
import '../../../core/models/security_status.dart';
import '../../../core/models/system_status.dart';
import 'mock_devices.dart';

/// Bundle of per-device detail data used by the detail screen.
/// Phase 11 will move this behind a service interface; shape is
/// already aligned with that future signature.
class MockDeviceDetail {
  final SystemStatus system;
  final SecurityStatus security;
  final List<NetworkAdapter> adapters;
  final List<Alert> alertHistory;
  final String serialNumber;
  final String domain;
  final DateTime enrolledAt;
  final List<String> tags;

  const MockDeviceDetail({
    required this.system,
    required this.security,
    required this.adapters,
    required this.alertHistory,
    required this.serialNumber,
    required this.domain,
    required this.enrolledAt,
    required this.tags,
  });

  /// Lookup a deterministic mock detail for any device in [MockDevices.all].
  /// Values are seeded off the device id so every device renders
  /// differently without random noise between rebuilds.
  factory MockDeviceDetail.forDeviceId(String deviceId) {
    final device = MockDevices.byId(deviceId);
    final seed = deviceId.codeUnits.fold<int>(0, (a, b) => a + b);

    final cpu = 15.0 + (seed % 55);
    final usedRam = 4.0 + ((seed % 7) * 1.3);
    final totalRam = usedRam + 6 + (seed % 10);
    final diskTotal = 256.0 + ((seed % 3) * 256);
    final diskUsed = diskTotal * (0.35 + ((seed % 50) / 100.0));
    final uptime = device?.uptimeSeconds ?? (seed * 733 % (14 * 24 * 3600));
    final hasBattery = (seed % 2 == 0); // laptops

    return MockDeviceDetail(
      system: SystemStatus(
        deviceId: deviceId,
        hostname: device?.hostname ?? deviceId,
        os: device?.os ?? 'Windows 11 Pro',
        osBuild: _osBuildFor(device?.osVersion ?? '23H2'),
        architecture: 'x64',
        cpuName: 'Intel Core i7-11700 @ 2.50GHz',
        cpuCores: 8,
        cpuUsagePercent: double.parse(cpu.toStringAsFixed(1)),
        totalRamGb: double.parse(totalRam.toStringAsFixed(1)),
        usedRamGb: double.parse(usedRam.toStringAsFixed(1)),
        diskTotalGb: diskTotal,
        diskUsedGb: double.parse(diskUsed.toStringAsFixed(1)),
        uptimeSeconds: uptime,
        batteryPercent: hasBattery ? 40 + (seed % 55) : null,
        isCharging: hasBattery ? (seed % 3 != 0) : null,
        timestamp: DateTime.now(),
      ),
      security: SecurityStatus(
        deviceId: deviceId,
        antivirusName: 'Windows Defender',
        antivirusEnabled: true,
        antivirusUpToDate: seed % 5 != 0,
        realTimeProtection: true,
        lastScanAt:
            DateTime.now().subtract(Duration(hours: 3 + (seed % 72))),
        firewallDomain: FirewallState.enabled,
        firewallPrivate: FirewallState.enabled,
        firewallPublic: seed % 7 == 0
            ? FirewallState.disabled
            : FirewallState.enabled,
        windowsActivated: true,
        bitLockerEnabled: seed % 2 == 0,
        lastUpdateCheck:
            DateTime.now().subtract(Duration(hours: 6 + (seed % 120))),
      ),
      adapters: [
        NetworkAdapter(
          id: '$deviceId-eth0',
          name: 'Intel Ethernet I219-LM',
          type: AdapterType.ethernet,
          macAddress: device?.macAddress ?? 'A4:5E:60:1C:77:02',
          ipAddress: device?.ipAddress ?? '192.168.1.10',
          subnetMask: '255.255.255.0',
          gateway: '192.168.1.1',
          dnsServers: const ['192.168.1.1', '8.8.8.8'],
          isConnected: true,
          linkSpeedMbps: 1000,
          bytesSent: 245000000 + seed * 13000,
          bytesReceived: 1820000000 + seed * 47000,
        ),
        NetworkAdapter(
          id: '$deviceId-wlan0',
          name: 'Intel Wi-Fi 6 AX201 160MHz',
          type: AdapterType.wifi,
          macAddress: 'A4:5E:60:1C:77:03',
          ipAddress: '10.8.0.42',
          subnetMask: '255.255.255.0',
          gateway: '10.8.0.1',
          dnsServers: const ['1.1.1.1', '8.8.8.8'],
          isConnected: seed % 2 == 0,
          linkSpeedMbps: 866.7,
          bytesSent: 14200000,
          bytesReceived: 98500000,
        ),
      ],
      alertHistory: _buildAlerts(deviceId, seed),
      serialNumber: 'MSH-${deviceId.replaceAll('dev-', '')}-${seed * 7}',
      domain: 'MISTRY-SHAH.LOCAL',
      enrolledAt: DateTime.now().subtract(Duration(days: 30 + (seed % 400))),
      tags: _tagsFor(deviceId),
    );
  }

  static String _osBuildFor(String version) {
    if (version.contains('22H2')) return '19045.4529';
    if (version.contains('21H2')) return '20348.2402';
    return '22631.3737';
  }

  static List<String> _tagsFor(String deviceId) {
    if (deviceId.contains('SVR') || deviceId.contains('svr')) {
      return ['Server', 'Production', 'Data Room'];
    }
    if (deviceId.contains('PART')) {
      return ['Partner', 'Priority'];
    }
    if (deviceId.contains('ARTICL') || deviceId.contains('articl')) {
      return ['Workstation', 'Articles'];
    }
    return ['Workstation', 'Office'];
  }

  static List<Alert> _buildAlerts(String deviceId, int seed) {
    return [
      Alert(
        id: '$deviceId-al-1',
        title: 'CPU usage spike above 80%',
        message:
            'Sustained 84% usage for 6 minutes while running Tally + Excel.',
        severity: AlertSeverity.medium,
        status: AlertStatus.resolved,
        category: AlertCategory.performance,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        deviceId: deviceId,
        source: 'Perf Monitor',
      ),
      Alert(
        id: '$deviceId-al-2',
        title: 'Disk free space below threshold',
        message:
            'Primary drive at 87% — cleanup recommended before month-end.',
        severity: AlertSeverity.high,
        status: seed % 2 == 0 ? AlertStatus.open : AlertStatus.acknowledged,
        category: AlertCategory.system,
        timestamp: DateTime.now().subtract(const Duration(hours: 11)),
        deviceId: deviceId,
        source: 'Disk Monitor',
      ),
      Alert(
        id: '$deviceId-al-3',
        title: 'Pending Windows security update',
        message: 'KB5039212 installed — reboot required to apply fully.',
        severity: AlertSeverity.info,
        status: AlertStatus.open,
        category: AlertCategory.system,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        deviceId: deviceId,
        source: 'Windows Update',
      ),
      Alert(
        id: '$deviceId-al-4',
        title: 'Unusual login time detected',
        message:
            'Interactive login at 23:47 local — outside working hours window.',
        severity: AlertSeverity.low,
        status: AlertStatus.resolved,
        category: AlertCategory.security,
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
        deviceId: deviceId,
        source: 'Event Log',
      ),
      Alert(
        id: '$deviceId-al-5',
        title: 'Device back online',
        message: 'Heartbeat resumed after 12 minute interruption.',
        severity: AlertSeverity.info,
        status: AlertStatus.resolved,
        category: AlertCategory.network,
        timestamp: DateTime.now().subtract(const Duration(days: 4)),
        deviceId: deviceId,
        source: 'Heartbeat',
      ),
    ];
  }
}
