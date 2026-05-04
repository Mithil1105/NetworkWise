import 'package:flutter/foundation.dart';

enum DeviceStatus { online, offline, warning, unknown }

enum HealthStatus { healthy, warning, critical, unknown }

DeviceStatus _parseDeviceStatus(Object? v) {
  return DeviceStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => DeviceStatus.unknown,
  );
}

HealthStatus _parseHealthStatus(Object? v) {
  return HealthStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => HealthStatus.unknown,
  );
}

/// A managed endpoint (workstation / laptop / server).
@immutable
class Device {
  final String id;
  final String hostname;
  /// Optional admin-assigned friendly label. Falls back to [hostname]
  /// when empty. Reflected in the DB `hostname_label` column.
  final String hostnameLabel;
  final String ipAddress;
  final String macAddress;
  final String os;
  final String osVersion;
  final String manufacturer;
  final String model;
  final String assignedUser;
  final String location;
  final List<String> tags;
  final DeviceStatus status;
  final HealthStatus health;
  final DateTime lastSeen;
  final int uptimeSeconds;
  /// Non-null means the device has been archived (hidden from the
  /// default Devices list).
  final DateTime? archivedAt;

  // ---- Hardware inventory (captured at enrolment, refreshed opportunistically)
  final String serialNumber;
  final String domain;
  final String cpuName;
  final int cpuCores;
  final String architecture;
  final double totalRamGb;
  final double diskTotalGb;

  // ---- Active window (latest, server-stamped each heartbeat)
  // `null` means the foreground was undefined at the latest tick
  // (locked desktop or session-0 service). The Edge Function only
  // overwrites these when the probe reports a non-empty title.
  final String? activeWindowTitle;
  final String? activeProcessName;
  final DateTime? activeWindowSeenAt;

  const Device({
    required this.id,
    required this.hostname,
    this.hostnameLabel = '',
    required this.ipAddress,
    required this.macAddress,
    required this.os,
    required this.osVersion,
    required this.manufacturer,
    required this.model,
    required this.assignedUser,
    required this.location,
    this.tags = const [],
    required this.status,
    required this.health,
    required this.lastSeen,
    required this.uptimeSeconds,
    this.archivedAt,
    this.serialNumber = '',
    this.domain = '',
    this.cpuName = '',
    this.cpuCores = 0,
    this.architecture = '',
    this.totalRamGb = 0,
    this.diskTotalGb = 0,
    this.activeWindowTitle,
    this.activeProcessName,
    this.activeWindowSeenAt,
  });

  /// Preferred display name — [hostnameLabel] if set, otherwise the
  /// real Windows [hostname].
  String get displayName =>
      hostnameLabel.trim().isEmpty ? hostname : hostnameLabel.trim();

  /// True when the device has been archived (soft-deleted).
  bool get isArchived => archivedAt != null;

  Device copyWith({
    String? id,
    String? hostname,
    String? hostnameLabel,
    String? ipAddress,
    String? macAddress,
    String? os,
    String? osVersion,
    String? manufacturer,
    String? model,
    String? assignedUser,
    String? location,
    List<String>? tags,
    DeviceStatus? status,
    HealthStatus? health,
    DateTime? lastSeen,
    int? uptimeSeconds,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    String? serialNumber,
    String? domain,
    String? cpuName,
    int? cpuCores,
    String? architecture,
    double? totalRamGb,
    double? diskTotalGb,
    String? activeWindowTitle,
    String? activeProcessName,
    DateTime? activeWindowSeenAt,
    bool clearActiveWindow = false,
  }) {
    return Device(
      id: id ?? this.id,
      hostname: hostname ?? this.hostname,
      hostnameLabel: hostnameLabel ?? this.hostnameLabel,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      os: os ?? this.os,
      osVersion: osVersion ?? this.osVersion,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      assignedUser: assignedUser ?? this.assignedUser,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      health: health ?? this.health,
      lastSeen: lastSeen ?? this.lastSeen,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      serialNumber: serialNumber ?? this.serialNumber,
      domain: domain ?? this.domain,
      cpuName: cpuName ?? this.cpuName,
      cpuCores: cpuCores ?? this.cpuCores,
      architecture: architecture ?? this.architecture,
      totalRamGb: totalRamGb ?? this.totalRamGb,
      diskTotalGb: diskTotalGb ?? this.diskTotalGb,
      activeWindowTitle: clearActiveWindow
          ? null
          : (activeWindowTitle ?? this.activeWindowTitle),
      activeProcessName: clearActiveWindow
          ? null
          : (activeProcessName ?? this.activeProcessName),
      activeWindowSeenAt: clearActiveWindow
          ? null
          : (activeWindowSeenAt ?? this.activeWindowSeenAt),
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        hostname: json['hostname'] as String,
        hostnameLabel: json['hostnameLabel'] as String? ?? '',
        ipAddress: json['ipAddress'] as String,
        macAddress: json['macAddress'] as String,
        os: json['os'] as String,
        osVersion: json['osVersion'] as String,
        manufacturer: json['manufacturer'] as String,
        model: json['model'] as String,
        assignedUser: json['assignedUser'] as String? ?? '',
        location: json['location'] as String? ?? '',
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        status: _parseDeviceStatus(json['status']),
        health: _parseHealthStatus(json['health']),
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0,
        archivedAt: json['archivedAt'] is String
            ? DateTime.tryParse(json['archivedAt'] as String)
            : null,
        serialNumber: json['serialNumber'] as String? ?? '',
        domain: json['domain'] as String? ?? '',
        cpuName: json['cpuName'] as String? ?? '',
        cpuCores: (json['cpuCores'] as num?)?.toInt() ?? 0,
        architecture: json['architecture'] as String? ?? '',
        totalRamGb: (json['totalRamGb'] as num?)?.toDouble() ?? 0,
        diskTotalGb: (json['diskTotalGb'] as num?)?.toDouble() ?? 0,
        activeWindowTitle: json['activeWindowTitle'] as String?,
        activeProcessName: json['activeProcessName'] as String?,
        activeWindowSeenAt: json['activeWindowSeenAt'] is String
            ? DateTime.tryParse(json['activeWindowSeenAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostname': hostname,
        'hostnameLabel': hostnameLabel,
        'ipAddress': ipAddress,
        'macAddress': macAddress,
        'os': os,
        'osVersion': osVersion,
        'manufacturer': manufacturer,
        'model': model,
        'assignedUser': assignedUser,
        'location': location,
        'tags': tags,
        'status': status.name,
        'health': health.name,
        'lastSeen': lastSeen.toIso8601String(),
        'uptimeSeconds': uptimeSeconds,
        if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
        'serialNumber': serialNumber,
        'domain': domain,
        'cpuName': cpuName,
        'cpuCores': cpuCores,
        'architecture': architecture,
        'totalRamGb': totalRamGb,
        'diskTotalGb': diskTotalGb,
        if (activeWindowTitle != null) 'activeWindowTitle': activeWindowTitle,
        if (activeProcessName != null) 'activeProcessName': activeProcessName,
        if (activeWindowSeenAt != null)
          'activeWindowSeenAt': activeWindowSeenAt!.toIso8601String(),
      };

  /// Deterministic mock for UI preview + tests.
  factory Device.mock({
    String id = 'dev-001',
    String hostname = 'WIN-OFFICE-01',
    DeviceStatus status = DeviceStatus.online,
    HealthStatus health = HealthStatus.healthy,
  }) {
    return Device(
      id: id,
      hostname: hostname,
      hostnameLabel: '',
      ipAddress: '192.168.1.24',
      macAddress: 'A4:5E:60:1C:77:02',
      os: 'Windows 11 Pro',
      osVersion: '23H2 (22631.3737)',
      manufacturer: 'Dell Inc.',
      model: 'OptiPlex 7090',
      assignedUser: 'priya.mehta',
      location: 'Ahmedabad — HQ',
      tags: const ['Workstation'],
      status: status,
      health: health,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      uptimeSeconds: 3 * 24 * 3600 + 4 * 3600,
      serialNumber: 'MSH-001-7A9F',
      domain: 'MISTRY-SHAH.LOCAL',
      cpuName: 'Intel(R) Core(TM) i7-11700 @ 2.50GHz',
      cpuCores: 8,
      architecture: 'x64',
      totalRamGb: 16,
      diskTotalGb: 512,
    );
  }
}
