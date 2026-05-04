import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/device_hardware_profile.dart';
import '../../models/system_status.dart';
import '../i_heartbeat_repository.dart';

/// Supabase-backed implementation of [IHeartbeatRepository].
///
/// Reads query the latest row from `heartbeat_logs` per device. Writes
/// are routed through the `report-heartbeat` Edge Function so the
/// server can bump `devices.last_seen_at` in a single round-trip.
class SupabaseHeartbeatRepository implements IHeartbeatRepository {
  SupabaseHeartbeatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SystemStatus?> latestForDevice(String deviceId) async {
    final row = await _client
        .from('heartbeat_logs')
        .select()
        .eq('device_id', deviceId)
        .order('reported_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _mapRow(deviceId: deviceId, row: row);
  }

  @override
  Future<void> reportHeartbeat({
    required String deviceId,
    required String registrationSecret,
    required SystemStatus sample,
    DeviceHardwareProfile? profile,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'registration_secret': registrationSecret,
      'cpu_usage_percent': sample.cpuUsagePercent,
      'memory_used_gb': sample.usedRamGb,
      'memory_total_gb': sample.totalRamGb,
      'disk_used_gb': sample.diskUsedGb,
      'disk_total_gb': sample.diskTotalGb,
      if (sample.batteryPercent != null)
        'battery_percent': sample.batteryPercent,
      if (sample.isCharging != null) 'is_charging': sample.isCharging,
      'uptime_seconds': sample.uptimeSeconds,
      // Hostname moves with the machine, so even without a full hardware
      // profile refresh we keep it in sync when the probe knows it.
      if (sample.hostname.trim().isNotEmpty) 'hostname': sample.hostname.trim(),
      // Active window (Phase 20) — the Edge Function patches the
      // matching `devices.active_window_*` columns. We send the raw
      // strings; if the foreground was undefined (locked desktop /
      // session 0) the probe leaves both fields null and the keys
      // simply aren't present.
      if (sample.activeWindowTitle != null &&
          sample.activeWindowTitle!.trim().isNotEmpty)
        'active_window_title': sample.activeWindowTitle!.trim(),
      if (sample.activeProcessName != null &&
          sample.activeProcessName!.trim().isNotEmpty)
        'active_process_name': sample.activeProcessName!.trim(),
      // Per-volume disks (Phase 21). Sent as an array of plain Maps so
      // PostgREST stores it directly in the JSONB column without any
      // server-side massaging.
      if (sample.disks.isNotEmpty)
        'disks': sample.disks.map((d) => d.toJson()).toList(growable: false),
    };

    if (profile != null) {
      if (profile.ipAddress.isNotEmpty) body['ip_address'] = profile.ipAddress;
      if (profile.macAddress.isNotEmpty) body['mac_address'] = profile.macAddress;
      if (profile.manufacturer.isNotEmpty) {
        body['manufacturer'] = profile.manufacturer;
      }
      if (profile.model.isNotEmpty) body['model'] = profile.model;
      if (profile.serialNumber.isNotEmpty) {
        body['serial_number'] = profile.serialNumber;
      }
      if (profile.domain.isNotEmpty) body['domain'] = profile.domain;
      if (profile.cpuName.isNotEmpty) body['cpu_name'] = profile.cpuName;
      if (profile.cpuCores > 0) body['cpu_cores'] = profile.cpuCores;
      if (profile.architecture.isNotEmpty) {
        body['architecture'] = profile.architecture;
      }
      if (profile.totalRamGb > 0) body['total_ram_gb'] = profile.totalRamGb;
    }

    final response =
        await _client.functions.invoke('report-heartbeat', body: body);
    if (response.status != null && response.status! >= 400) {
      throw StateError(
        'report-heartbeat failed (${response.status}): ${response.data}',
      );
    }
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  SystemStatus _mapRow({
    required String deviceId,
    required Map<String, dynamic> row,
  }) {
    // heartbeat_logs stores only the telemetry slice — we fill the
    // static fields (hostname, os, cpuName, cpuCores, osBuild, arch)
    // with sensible placeholders; the device detail screen hydrates
    // those from the devices table.
    return SystemStatus(
      deviceId: deviceId,
      hostname: '',
      os: '',
      osBuild: '',
      architecture: 'x64',
      cpuName: '',
      cpuCores: 0,
      cpuUsagePercent: (row['cpu_usage_percent'] as num?)?.toDouble() ?? 0,
      totalRamGb: (row['memory_total_gb'] as num?)?.toDouble() ?? 0,
      usedRamGb: (row['memory_used_gb'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (row['disk_total_gb'] as num?)?.toDouble() ?? 0,
      diskUsedGb: (row['disk_used_gb'] as num?)?.toDouble() ?? 0,
      uptimeSeconds: (row['uptime_seconds'] as num?)?.toInt() ?? 0,
      batteryPercent: (row['battery_percent'] as num?)?.toInt(),
      isCharging: row['is_charging'] as bool?,
      timestamp: DateTime.parse(row['reported_at'] as String),
    );
  }
}
