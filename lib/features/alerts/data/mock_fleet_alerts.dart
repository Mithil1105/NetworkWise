import '../../../core/models/alert.dart';

/// Inline mock alert feed. Roughly 28 alerts spanning every severity,
/// status and category, bound to the 14 devices in
/// [MockDevices.all]. Replaced by `MockDataService` in Phase 11.
class MockFleetAlerts {
  const MockFleetAlerts._();

  static final DateTime _now = DateTime.now();

  static final List<Alert> all = [
    // ---------------- Critical / high — open ----------------
    Alert(
      id: 'alrt-001',
      title: 'BitLocker disabled on partner laptop',
      message:
          'Drive C: on WIN-PART-02 is reporting as decrypted. Policy requires '
          'full-disk encryption on all partner machines.',
      severity: AlertSeverity.critical,
      status: AlertStatus.open,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(minutes: 8)),
      deviceId: 'dev-009',
      source: 'BitLocker',
    ),
    Alert(
      id: 'alrt-002',
      title: 'Defender signatures outdated',
      message:
          'Windows Defender signatures on WIN-ACC-03 were last updated 3 '
          'days ago. Signature sync has been failing silently.',
      severity: AlertSeverity.high,
      status: AlertStatus.open,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(minutes: 18)),
      deviceId: 'dev-002',
      source: 'Defender',
    ),
    Alert(
      id: 'alrt-003',
      title: 'Disk volume almost full',
      message:
          'C: drive on WIN-HR-02 is at 94% capacity. Risk of service '
          'disruption — recommend cleanup or expansion.',
      severity: AlertSeverity.high,
      status: AlertStatus.open,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(minutes: 34)),
      deviceId: 'dev-003',
      source: 'WMI',
    ),
    Alert(
      id: 'alrt-004',
      title: 'Device offline beyond threshold',
      message:
          'WIN-LEGACY-02 has been unreachable for over 48 hours. Last seen '
          'at ${_now.subtract(const Duration(days: 2))}.',
      severity: AlertSeverity.critical,
      status: AlertStatus.open,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(hours: 47)),
      deviceId: 'dev-013',
      source: 'Heartbeat',
    ),
    Alert(
      id: 'alrt-005',
      title: 'Windows activation expired',
      message:
          'WIN-LEGACY-02 reports deactivated status — KMS grace period has '
          'elapsed. Licensing intervention required.',
      severity: AlertSeverity.high,
      status: AlertStatus.open,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(hours: 22)),
      deviceId: 'dev-013',
      source: 'SLMGR',
    ),

    // ---------------- Medium — open ----------------
    Alert(
      id: 'alrt-006',
      title: 'Firewall — public profile off',
      message:
          'Public firewall profile on WIN-ARTICL-05 is disabled. Re-enable '
          'via Group Policy or manual toggle.',
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(hours: 1, minutes: 12)),
      deviceId: 'dev-011',
      source: 'NetSh',
    ),
    Alert(
      id: 'alrt-007',
      title: 'High memory utilisation',
      message:
          'Sustained RAM usage above 88% on WIN-ACC-03 for 30+ minutes. '
          'Tally and Excel sessions dominating working set.',
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      category: AlertCategory.performance,
      timestamp: _now.subtract(const Duration(hours: 2, minutes: 5)),
      deviceId: 'dev-002',
      source: 'Perfmon',
    ),
    Alert(
      id: 'alrt-008',
      title: 'Windows Update pending reboot',
      message:
          'WIN-ARTICL-05 has cumulative update KB5037853 staged but awaiting '
          'a reboot since Friday.',
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(hours: 4, minutes: 40)),
      deviceId: 'dev-011',
      source: 'WUAUSERV',
    ),
    Alert(
      id: 'alrt-009',
      title: 'CPU spike detected',
      message:
          'WIN-PART-02 hit 96% CPU for 8 minutes running browser + Zoom + '
          'Tally concurrently.',
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      category: AlertCategory.performance,
      timestamp: _now.subtract(const Duration(hours: 6, minutes: 30)),
      deviceId: 'dev-009',
      source: 'Perfmon',
    ),
    Alert(
      id: 'alrt-010',
      title: 'Unusual outbound traffic',
      message:
          'WIN-TAX-05 pushed 2.1 GB outbound in 10 minutes to an unknown IP '
          'before going offline.',
      severity: AlertSeverity.high,
      status: AlertStatus.open,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(hours: 3, minutes: 10)),
      deviceId: 'dev-005',
      source: 'Firewall Log',
    ),

    // ---------------- Low / info — open ----------------
    Alert(
      id: 'alrt-011',
      title: 'Battery below 20%',
      message:
          'WIN-PART-01 battery at 18% and unplugged. User should connect '
          'power to avoid unexpected shutdown.',
      severity: AlertSeverity.low,
      status: AlertStatus.open,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(minutes: 42)),
      deviceId: 'dev-008',
      source: 'Power',
    ),
    Alert(
      id: 'alrt-012',
      title: 'New device joined domain',
      message:
          'WIN-ADMIN-01 has registered to MISTRY-SHAH.LOCAL and pulled the '
          'baseline policy bundle.',
      severity: AlertSeverity.info,
      status: AlertStatus.open,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(days: 1, hours: 2)),
      deviceId: 'dev-014',
      source: 'Active Directory',
    ),
    Alert(
      id: 'alrt-013',
      title: 'Scheduled scan completed',
      message:
          'Defender quick-scan on WIN-IT-SVR-01 finished in 4m12s — no '
          'threats found.',
      severity: AlertSeverity.info,
      status: AlertStatus.open,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(hours: 8)),
      deviceId: 'dev-006',
      source: 'Defender',
    ),
    Alert(
      id: 'alrt-014',
      title: 'Wi-Fi adapter flapping',
      message:
          'WIN-REC-04 disconnected and reconnected to M&S-Guest five times '
          'in the last hour.',
      severity: AlertSeverity.low,
      status: AlertStatus.open,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(hours: 1, minutes: 50)),
      deviceId: 'dev-007',
      source: 'NetEvent',
    ),

    // ---------------- Acknowledged ----------------
    Alert(
      id: 'alrt-015',
      title: 'Temperature threshold exceeded',
      message:
          'WIN-IT-SVR-01 CPU package hit 84°C during overnight backup — IT '
          'admin is monitoring airflow.',
      severity: AlertSeverity.medium,
      status: AlertStatus.acknowledged,
      category: AlertCategory.performance,
      timestamp: _now.subtract(const Duration(hours: 14)),
      deviceId: 'dev-006',
      source: 'IPMI',
    ),
    Alert(
      id: 'alrt-016',
      title: 'Suspicious login outside India',
      message:
          'Admin user attempted Citrix login from 103.47.x.x (Singapore). '
          'Session blocked; user has been notified.',
      severity: AlertSeverity.high,
      status: AlertStatus.acknowledged,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(hours: 19)),
      deviceId: 'dev-014',
      source: 'Citrix Audit',
    ),
    Alert(
      id: 'alrt-017',
      title: 'SMB share latency degraded',
      message:
          'Access to \\\\WIN-IT-SVR-01\\Clients averaging 620ms — affecting '
          'audit team file opens.',
      severity: AlertSeverity.medium,
      status: AlertStatus.acknowledged,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(hours: 21)),
      deviceId: 'dev-006',
      source: 'Perfmon',
    ),
    Alert(
      id: 'alrt-018',
      title: 'Disk I/O bottleneck',
      message:
          'WIN-ARTICL-06 HDD queue depth averaging 18 for 15 minutes during '
          'Tally end-of-day.',
      severity: AlertSeverity.low,
      status: AlertStatus.acknowledged,
      category: AlertCategory.performance,
      timestamp: _now.subtract(const Duration(days: 1, hours: 3)),
      deviceId: 'dev-012',
      source: 'Perfmon',
    ),
    Alert(
      id: 'alrt-019',
      title: 'Driver update available',
      message:
          'Intel Wi-Fi driver 22.240 available on WIN-OFFICE-01 — optional '
          'update via Dell Command.',
      severity: AlertSeverity.info,
      status: AlertStatus.acknowledged,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(days: 1, hours: 8)),
      deviceId: 'dev-001',
      source: 'Dell Command',
    ),

    // ---------------- Resolved ----------------
    Alert(
      id: 'alrt-020',
      title: 'Printer queue service failed',
      message:
          'Spooler service was hung on WIN-ADMIN-01. Service restarted — '
          'print queue recovered.',
      severity: AlertSeverity.medium,
      status: AlertStatus.resolved,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(days: 2, hours: 1)),
      deviceId: 'dev-014',
      source: 'Spooler',
    ),
    Alert(
      id: 'alrt-021',
      title: 'Defender signatures restored',
      message:
          'Signatures on WIN-GST-11 were 36 hours stale; forced update via '
          'mpcmdrun completed successfully.',
      severity: AlertSeverity.low,
      status: AlertStatus.resolved,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(days: 2, hours: 4)),
      deviceId: 'dev-010',
      source: 'Defender',
    ),
    Alert(
      id: 'alrt-022',
      title: 'DNS resolution failing',
      message:
          'Internal DNS lookups for mistry-shah.local failed on WIN-HR-02 '
          'for 40 minutes — resolved after primary DNS reboot.',
      severity: AlertSeverity.high,
      status: AlertStatus.resolved,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(days: 2, hours: 18)),
      deviceId: 'dev-003',
      source: 'DNSClient',
    ),
    Alert(
      id: 'alrt-023',
      title: 'Unauthorised USB mass storage',
      message:
          'Unknown 32 GB USB drive inserted on WIN-AUDIT-01; blocked by '
          'endpoint policy and user counselled.',
      severity: AlertSeverity.high,
      status: AlertStatus.resolved,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(days: 3)),
      deviceId: 'dev-004',
      source: 'Endpoint Policy',
    ),
    Alert(
      id: 'alrt-024',
      title: 'Patch rollout completed',
      message:
          'March security rollup deployed to 12 of 14 machines — two '
          'offline devices pending.',
      severity: AlertSeverity.info,
      status: AlertStatus.resolved,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(days: 4)),
      source: 'WSUS',
    ),
    Alert(
      id: 'alrt-025',
      title: 'Backup job succeeded',
      message:
          'Veeam job "Client-Data-Nightly" completed in 54m, 212 GB '
          'processed, 0 errors.',
      severity: AlertSeverity.info,
      status: AlertStatus.resolved,
      category: AlertCategory.system,
      timestamp: _now.subtract(const Duration(days: 1, hours: 14)),
      deviceId: 'dev-006',
      source: 'Veeam',
    ),
    Alert(
      id: 'alrt-026',
      title: 'Firewall profile re-enabled',
      message:
          'Domain firewall profile on WIN-OFFICE-01 was auto-remediated '
          'after Group Policy refresh.',
      severity: AlertSeverity.low,
      status: AlertStatus.resolved,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(days: 1, hours: 20)),
      deviceId: 'dev-001',
      source: 'NetSh',
    ),

    // ---------------- Additional flavour ----------------
    Alert(
      id: 'alrt-027',
      title: 'New admin privilege granted',
      message:
          'Local admin rights granted to user kiran.mistry on WIN-AUDIT-01 '
          'for quarter-end audit window.',
      severity: AlertSeverity.medium,
      status: AlertStatus.acknowledged,
      category: AlertCategory.security,
      timestamp: _now.subtract(const Duration(hours: 10)),
      deviceId: 'dev-004',
      source: 'Active Directory',
    ),
    Alert(
      id: 'alrt-028',
      title: 'Tally license server unreachable',
      message:
          'WIN-GST-11 cannot reach the Tally license server on port 9000 — '
          'fallback local licence in use.',
      severity: AlertSeverity.medium,
      status: AlertStatus.open,
      category: AlertCategory.network,
      timestamp: _now.subtract(const Duration(hours: 5, minutes: 15)),
      deviceId: 'dev-010',
      source: 'Tally',
    ),
  ];

  /// Returns alerts sorted by timestamp descending (newest first).
  static List<Alert> sortedByRecency() {
    final list = List<Alert>.from(all);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}
