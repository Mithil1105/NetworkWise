import 'package:flutter/foundation.dart';

import 'disk_volume.dart';

/// Point-in-time system telemetry — CPU, RAM, disk, uptime, battery.
@immutable
class SystemStatus {
  final String deviceId;
  final String hostname;
  final String os;
  final String osBuild;
  final String architecture;

  // CPU
  final String cpuName;
  final int cpuCores;
  final double cpuUsagePercent;

  // Memory (GB)
  final double totalRamGb;
  final double usedRamGb;

  // Aggregate disk (sum across every fixed volume — back-compat with
  // older heartbeat_logs columns that only carry one number).
  final double diskTotalGb;
  final double diskUsedGb;

  // Per-volume breakdown — one entry per fixed `Win32_LogicalDisk`
  // (DriveType=3). Empty list on probe failure or non-Windows hosts;
  // never null so iterating in the UI is safe.
  final List<DiskVolume> disks;

  // Misc
  final int uptimeSeconds;
  final int? batteryPercent; // null on desktops
  final bool? isCharging;
  final DateTime timestamp;

  // Active window — what the user is currently working on. Captured via
  // GetForegroundWindow()/GetWindowText() + the owning process name on
  // each heartbeat tick. Both fields are nullable because the foreground
  // is undefined when the desktop is locked / no GUI session is active.
  final String? activeWindowTitle;
  final String? activeProcessName;

  const SystemStatus({
    required this.deviceId,
    required this.hostname,
    required this.os,
    required this.osBuild,
    required this.architecture,
    required this.cpuName,
    required this.cpuCores,
    required this.cpuUsagePercent,
    required this.totalRamGb,
    required this.usedRamGb,
    required this.diskTotalGb,
    required this.diskUsedGb,
    required this.uptimeSeconds,
    required this.batteryPercent,
    required this.isCharging,
    required this.timestamp,
    this.activeWindowTitle,
    this.activeProcessName,
    this.disks = const <DiskVolume>[],
  });

  double get memoryUsagePercent =>
      totalRamGb == 0 ? 0 : (usedRamGb / totalRamGb) * 100.0;

  double get diskUsagePercent =>
      diskTotalGb == 0 ? 0 : (diskUsedGb / diskTotalGb) * 100.0;

  SystemStatus copyWith({
    String? deviceId,
    String? hostname,
    String? os,
    String? osBuild,
    String? architecture,
    String? cpuName,
    int? cpuCores,
    double? cpuUsagePercent,
    double? totalRamGb,
    double? usedRamGb,
    double? diskTotalGb,
    double? diskUsedGb,
    int? uptimeSeconds,
    int? batteryPercent,
    bool? isCharging,
    DateTime? timestamp,
    String? activeWindowTitle,
    String? activeProcessName,
    List<DiskVolume>? disks,
  }) {
    return SystemStatus(
      deviceId: deviceId ?? this.deviceId,
      hostname: hostname ?? this.hostname,
      os: os ?? this.os,
      osBuild: osBuild ?? this.osBuild,
      architecture: architecture ?? this.architecture,
      cpuName: cpuName ?? this.cpuName,
      cpuCores: cpuCores ?? this.cpuCores,
      cpuUsagePercent: cpuUsagePercent ?? this.cpuUsagePercent,
      totalRamGb: totalRamGb ?? this.totalRamGb,
      usedRamGb: usedRamGb ?? this.usedRamGb,
      diskTotalGb: diskTotalGb ?? this.diskTotalGb,
      diskUsedGb: diskUsedGb ?? this.diskUsedGb,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isCharging: isCharging ?? this.isCharging,
      timestamp: timestamp ?? this.timestamp,
      activeWindowTitle: activeWindowTitle ?? this.activeWindowTitle,
      activeProcessName: activeProcessName ?? this.activeProcessName,
      disks: disks ?? this.disks,
    );
  }

  factory SystemStatus.fromJson(Map<String, dynamic> json) => SystemStatus(
        deviceId: json['deviceId'] as String,
        hostname: json['hostname'] as String,
        os: json['os'] as String,
        osBuild: json['osBuild'] as String? ?? '',
        architecture: json['architecture'] as String? ?? 'x64',
        cpuName: json['cpuName'] as String? ?? 'Unknown CPU',
        cpuCores: (json['cpuCores'] as num?)?.toInt() ?? 0,
        cpuUsagePercent: (json['cpuUsagePercent'] as num?)?.toDouble() ?? 0,
        totalRamGb: (json['totalRamGb'] as num?)?.toDouble() ?? 0,
        usedRamGb: (json['usedRamGb'] as num?)?.toDouble() ?? 0,
        diskTotalGb: (json['diskTotalGb'] as num?)?.toDouble() ?? 0,
        diskUsedGb: (json['diskUsedGb'] as num?)?.toDouble() ?? 0,
        uptimeSeconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0,
        batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
        isCharging: json['isCharging'] as bool?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        activeWindowTitle: json['activeWindowTitle'] as String?,
        activeProcessName: json['activeProcessName'] as String?,
        disks: (json['disks'] as List?)
                ?.whereType<Map>()
                .map((e) => DiskVolume.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const <DiskVolume>[],
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'hostname': hostname,
        'os': os,
        'osBuild': osBuild,
        'architecture': architecture,
        'cpuName': cpuName,
        'cpuCores': cpuCores,
        'cpuUsagePercent': cpuUsagePercent,
        'totalRamGb': totalRamGb,
        'usedRamGb': usedRamGb,
        'diskTotalGb': diskTotalGb,
        'diskUsedGb': diskUsedGb,
        'uptimeSeconds': uptimeSeconds,
        'batteryPercent': batteryPercent,
        'isCharging': isCharging,
        'timestamp': timestamp.toIso8601String(),
        'activeWindowTitle': activeWindowTitle,
        'activeProcessName': activeProcessName,
        'disks': disks.map((d) => d.toJson()).toList(growable: false),
      };

  factory SystemStatus.mock({
    String deviceId = 'dev-001',
    String hostname = 'WIN-OFFICE-01',
  }) =>
      SystemStatus(
        deviceId: deviceId,
        hostname: hostname,
        os: 'Windows 11 Pro',
        osBuild: '22631.3737',
        architecture: 'x64',
        cpuName: 'Intel Core i7-11700 @ 2.50GHz',
        cpuCores: 8,
        cpuUsagePercent: 27.4,
        totalRamGb: 16.0,
        usedRamGb: 9.8,
        diskTotalGb: 512.0,
        diskUsedGb: 287.5,
        uptimeSeconds: 3 * 24 * 3600 + 4 * 3600,
        batteryPercent: null,
        isCharging: null,
        timestamp: DateTime.now(),
      );
}
