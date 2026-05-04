import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert.dart';
import '../models/antivirus_product.dart';
import '../models/device_hardware_profile.dart';
import '../models/security_status.dart';
import '../models/system_status.dart';
import '../repositories/supabase/supabase_repositories_providers.dart';
import '../services/device_identity_provider.dart';
import 'sync_queue.dart';

/// Singleton queue for the entire app lifetime. The provider itself
/// creates the [SyncQueue] eagerly; the caller should [SyncQueue.load]
/// followed by [SyncQueue.start] from `main.dart` (after bootstrap).
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final queue = SyncQueue();
  ref.onDispose(queue.stop);
  return queue;
});

/// Executor bound to the current repositories and device identity.
///
/// Wire it up once after bootstrap completes:
///
/// ```dart
///   final queue = ref.read(syncQueueProvider);
///   await queue.load();
///   queue.start(ref.read(syncQueueExecutorProvider));
/// ```
///
/// Heartbeat + adapter snapshot payloads must be shaped by the
/// `HeartbeatLoop` (Phase 13) using the serialisation helpers defined
/// below — keeping both sides in this file makes the contract explicit.
final syncQueueExecutorProvider = Provider<SyncExecutor>((ref) {
  final alertsRepo = ref.watch(supabaseAlertsRepositoryProvider);
  final heartbeatRepo = ref.watch(supabaseHeartbeatRepositoryProvider);
  final adaptersRepo = ref.watch(supabaseNetworkAdaptersRepositoryProvider);
  final securityRepo = ref.watch(supabaseSecurityRepositoryProvider);
  final identity = ref.watch(deviceIdentityServiceProvider);

  return (op) async {
    final deviceId = identity.current?.deviceUuid;
    final secret = identity.currentRegistrationSecret;
    if (deviceId == null || secret == null) {
      // Not registered yet — stay in the queue until bootstrap finishes.
      return false;
    }

    try {
      switch (op.kind) {
        case SyncOpKind.heartbeat:
          await heartbeatRepo.reportHeartbeat(
            deviceId: deviceId,
            registrationSecret: secret,
            sample: _systemStatusFromJson(op.payload),
            profile: _profileFromJson(op.payload),
          );
          return true;

        case SyncOpKind.snapshot:
          // The heartbeat loop will serialise adapters inline; we
          // currently only drain the adapter portion, since security
          // is also sent in the same `report-snapshot` Edge Function.
          // Phase 13 will serialise the full SecurityStatus into the
          // payload and call the combined submitSnapshot helper.
          // Phase 13 will decode the serialised adapter list off the
          // payload. For now we just replay an empty set so the queue
          // plumbing is exercised end-to-end; adapters will not
          // actually be wiped because the server handles the empty
          // array as "no change" when `security` is empty too.
          await adaptersRepo.replaceAdaptersForDevice(
            deviceId: deviceId,
            registrationSecret: secret,
            adapters: const [],
          );
          return true;

        case SyncOpKind.securitySnapshot:
          // Phase 18 — append a full SecurityStatus + multi-AV
          // inventory via the `report-snapshot` Edge Function. The
          // security repository's `appendSnapshot` already shapes the
          // payload correctly; we just reconstruct the status object
          // from the queued JSON.
          await securityRepo.appendSnapshot(
            deviceId: deviceId,
            registrationSecret: secret,
            snapshot: _securityStatusFromJson(op.payload)
                .copyWith(deviceId: deviceId),
          );
          return true;

        case SyncOpKind.reportAlert:
          await alertsRepo.reportAlert(
            deviceId: deviceId,
            registrationSecret: secret,
            title: op.payload['title'] as String,
            message: op.payload['message'] as String?,
            severity: _parseSeverity(op.payload['severity'] as String?),
            category: _parseCategory(op.payload['category'] as String?),
            source: op.payload['source'] as String?,
            occurredAt: op.payload['occurred_at'] is String
                ? DateTime.parse(op.payload['occurred_at'] as String)
                : null,
          );
          return true;

        case SyncOpKind.acknowledgeAlert:
          await alertsRepo.acknowledgeAlert(
            deviceId: deviceId,
            registrationSecret: secret,
            alertId: op.payload['alert_id'] as String,
            actor: op.payload['actor'] as String?,
          );
          return true;

        case SyncOpKind.resolveAlert:
          await alertsRepo.resolveAlert(
            deviceId: deviceId,
            registrationSecret: secret,
            alertId: op.payload['alert_id'] as String,
            actor: op.payload['actor'] as String?,
          );
          return true;
      }
    } catch (_) {
      // Transient failure — leave the op in the queue.
      return false;
    }
  };
});

// ---------------------------------------------------------------------------
// Payload helpers — shared by the HeartbeatLoop (writer) and the executor
// (reader). Keep the shape stable across releases or bump the queue storage
// key in `SyncQueue._storageKey`.
// ---------------------------------------------------------------------------

Map<String, dynamic> systemStatusToSyncJson(
  SystemStatus s, {
  DeviceHardwareProfile? profile,
}) {
  final json = <String, dynamic>{
    'device_id': s.deviceId,
    'hostname': s.hostname,
    'cpu_usage_percent': s.cpuUsagePercent,
    'memory_used_gb': s.usedRamGb,
    'memory_total_gb': s.totalRamGb,
    'disk_used_gb': s.diskUsedGb,
    'disk_total_gb': s.diskTotalGb,
    if (s.batteryPercent != null) 'battery_percent': s.batteryPercent,
    if (s.isCharging != null) 'is_charging': s.isCharging,
    'uptime_seconds': s.uptimeSeconds,
    'timestamp': s.timestamp.toIso8601String(),
    // Active window — captured at probe time. Both fields are nullable
    // because the foreground is undefined when the desktop is locked.
    // The Edge Function patches devices.active_window_* off these keys.
    if (s.activeWindowTitle != null) 'active_window_title': s.activeWindowTitle,
    if (s.activeProcessName != null) 'active_process_name': s.activeProcessName,
  };
  if (profile != null) {
    // Nest the hardware profile under a dedicated key so the telemetry
    // half of the payload stays stable for callers that don't care
    // about the inventory refresh.
    json['hardware_profile'] = <String, dynamic>{
      'manufacturer': profile.manufacturer,
      'model': profile.model,
      'serial_number': profile.serialNumber,
      'domain': profile.domain,
      'mac_address': profile.macAddress,
      'ip_address': profile.ipAddress,
      'cpu_name': profile.cpuName,
      'cpu_cores': profile.cpuCores,
      'architecture': profile.architecture,
      'total_ram_gb': profile.totalRamGb,
      'disk_total_gb': profile.diskTotalGb,
    };
  }
  return json;
}

SystemStatus _systemStatusFromJson(Map<String, dynamic> p) => SystemStatus(
      deviceId: (p['device_id'] as String?) ?? '',
      hostname: (p['hostname'] as String?) ?? '',
      os: '',
      osBuild: '',
      architecture: 'x64',
      cpuName: '',
      cpuCores: 0,
      cpuUsagePercent: (p['cpu_usage_percent'] as num?)?.toDouble() ?? 0,
      totalRamGb: (p['memory_total_gb'] as num?)?.toDouble() ?? 0,
      usedRamGb: (p['memory_used_gb'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (p['disk_total_gb'] as num?)?.toDouble() ?? 0,
      diskUsedGb: (p['disk_used_gb'] as num?)?.toDouble() ?? 0,
      uptimeSeconds: (p['uptime_seconds'] as num?)?.toInt() ?? 0,
      batteryPercent: (p['battery_percent'] as num?)?.toInt(),
      isCharging: p['is_charging'] as bool?,
      timestamp: p['timestamp'] is String
          ? DateTime.parse(p['timestamp'] as String)
          : DateTime.now().toUtc(),
      activeWindowTitle: p['active_window_title'] as String?,
      activeProcessName: p['active_process_name'] as String?,
    );

DeviceHardwareProfile? _profileFromJson(Map<String, dynamic> p) {
  final raw = p['hardware_profile'];
  if (raw is! Map) return null;
  final j = Map<String, dynamic>.from(raw);
  return DeviceHardwareProfile(
    manufacturer: (j['manufacturer'] as String?) ?? '',
    model: (j['model'] as String?) ?? '',
    serialNumber: (j['serial_number'] as String?) ?? '',
    domain: (j['domain'] as String?) ?? '',
    macAddress: (j['mac_address'] as String?) ?? '',
    ipAddress: (j['ip_address'] as String?) ?? '',
    cpuName: (j['cpu_name'] as String?) ?? '',
    cpuCores: (j['cpu_cores'] as num?)?.toInt() ?? 0,
    architecture: (j['architecture'] as String?) ?? '',
    totalRamGb: (j['total_ram_gb'] as num?)?.toDouble() ?? 0,
    diskTotalGb: (j['disk_total_gb'] as num?)?.toDouble() ?? 0,
  );
}

AlertSeverity _parseSeverity(String? raw) => AlertSeverity.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AlertSeverity.info,
    );

AlertCategory _parseCategory(String? raw) => AlertCategory.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AlertCategory.other,
    );

// ---------------------------------------------------------------------------
// SecurityStatus queue payload (Phase 18).
//
// The probe produces a rich object — multi-AV list + firewall/activation/
// BitLocker/update metadata — so the payload is a verbatim round-trip of
// `SecurityStatus.toJson()` nested under the `status` key.  The queue's
// executor reconstructs the object via [SecurityStatus.fromJson].
// ---------------------------------------------------------------------------

Map<String, dynamic> securityStatusToSyncJson(SecurityStatus s) {
  return <String, dynamic>{
    'status': s.toJson(),
  };
}

SecurityStatus _securityStatusFromJson(Map<String, dynamic> p) {
  final raw = p['status'];
  if (raw is! Map) {
    // Defensive fallback: return an empty posture keyed to whatever
    // device id the caller will patch in — the queue already logs the
    // payload when a non-retriable error fires.
    return SecurityStatus(
      deviceId: '',
      antivirusName: 'Unknown',
      antivirusEnabled: false,
      antivirusUpToDate: false,
      realTimeProtection: false,
      lastScanAt: null,
      firewallDomain: FirewallState.unknown,
      firewallPrivate: FirewallState.unknown,
      firewallPublic: FirewallState.unknown,
      windowsActivated: false,
      bitLockerEnabled: false,
      lastUpdateCheck: null,
      antivirusProducts: const <AntivirusProduct>[],
    );
  }
  return SecurityStatus.fromJson(Map<String, dynamic>.from(raw));
}
