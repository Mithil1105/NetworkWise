import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/device.dart';
import '../i_devices_repository.dart';

/// Supabase-backed implementation of [IDevicesRepository].
///
/// Reads go through PostgREST with the `x-org-id` header applied by
/// [SupabaseHeaders.applyOrganization]. Writes that touch the
/// `registration_secret` (device provisioning) are routed through the
/// `register-device` Edge Function so the secret is never exposed
/// directly to the client.
class SupabaseDevicesRepository implements IDevicesRepository {
  SupabaseDevicesRepository(this._client);

  final SupabaseClient _client;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  @override
  Future<List<Device>> listDevices() async {
    final rows = await _client
        .from('devices')
        .select()
        .order('hostname', ascending: true);
    return rows
        .map((r) => _mapDeviceRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Device?> getDevice(String deviceId) async {
    final row = await _client
        .from('devices')
        .select()
        .eq('id', deviceId)
        .maybeSingle();
    if (row == null) return null;
    return _mapDeviceRow(row);
  }

  @override
  Stream<void> watchDevices() {
    // Broadcast a tick every time any row in `devices` changes for
    // the current organization. Filtering client-side is fine — the
    // RLS policy already scopes what Realtime can even emit.
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('public:devices')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  // ------------------------------------------------------------------
  // Writes
  // ------------------------------------------------------------------

  @override
  Future<DeviceRegistrationReceipt> registerDevice({
    required String deviceUuid,
    String? enrollmentCode,
    String? orgSlug,
    required String hostname,
    required String os,
    required String osVersion,
    required String manufacturer,
    required String model,
    required String macAddress,
    String? ipAddress,
    String? assignedUser,
    String? location,
    String? serialNumber,
    String? domain,
    String? cpuName,
    int? cpuCores,
    String? architecture,
    double? totalRamGb,
    double? diskTotalGb,
    String? environment,
  }) async {
    if ((enrollmentCode == null || enrollmentCode.isEmpty) &&
        (orgSlug == null || orgSlug.isEmpty)) {
      throw ArgumentError(
        'registerDevice requires either enrollmentCode (preferred) or orgSlug.',
      );
    }
    final response = await _client.functions.invoke(
      'register-device',
      body: <String, dynamic>{
        'device_uuid': deviceUuid,
        if (enrollmentCode != null && enrollmentCode.isNotEmpty)
          'enrollment_code': enrollmentCode,
        if (orgSlug != null && orgSlug.isNotEmpty) 'org_slug': orgSlug,
        'hostname': hostname,
        'os': os,
        'os_version': osVersion,
        'manufacturer': manufacturer,
        'model': model,
        'mac_address': macAddress,
        if (ipAddress != null) 'ip_address': ipAddress,
        if (assignedUser != null) 'assigned_user': assignedUser,
        if (location != null) 'location': location,
        if (serialNumber != null) 'serial_number': serialNumber,
        if (domain != null) 'domain': domain,
        if (cpuName != null) 'cpu_name': cpuName,
        if (cpuCores != null) 'cpu_cores': cpuCores,
        if (architecture != null) 'architecture': architecture,
        if (totalRamGb != null) 'total_ram_gb': totalRamGb,
        if (diskTotalGb != null) 'disk_total_gb': diskTotalGb,
        if (environment != null) 'environment': environment,
      },
    );
    if (response.status != null &&
        response.status! >= 400 &&
        response.status! < 600) {
      throw StateError(
        'register-device failed (${response.status}): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map ||
        data['registration_secret'] is! String ||
        data['organization_id'] is! String ||
        data['device_id'] is! String) {
      throw StateError(
        'register-device returned an unexpected payload: $data',
      );
    }
    final enrolledAt = data['enrolled_at'] is String
        ? DateTime.parse(data['enrolled_at'] as String)
        : DateTime.now().toUtc();
    return DeviceRegistrationReceipt(
      deviceId: data['device_id'] as String,
      organizationId: data['organization_id'] as String,
      registrationSecret: data['registration_secret'] as String,
      enrolledAt: enrolledAt,
    );
  }

  @override
  Future<void> touchLastSeen(String deviceId) async {
    // The heartbeat Edge Function already bumps last_seen_at on every
    // successful POST — this method exists for parity with the mock
    // repo and for tests that want to force the timestamp.
    await _client
        .from('devices')
        .update({'last_seen_at': DateTime.now().toIso8601String()})
        .eq('id', deviceId);
  }

  @override
  Future<Device> updateDevice({
    required String deviceId,
    String? hostnameLabel,
    String? assignedUser,
    String? location,
    List<String>? tags,
    bool? archived,
  }) async {
    final patch = <String, dynamic>{
      if (hostnameLabel != null)
        'hostname_label':
            hostnameLabel.trim().isEmpty ? null : hostnameLabel.trim(),
      if (assignedUser != null)
        'assigned_user':
            assignedUser.trim().isEmpty ? null : assignedUser.trim(),
      if (location != null)
        'location': location.trim().isEmpty ? null : location.trim(),
      if (tags != null)
        'tags': tags
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList(growable: false),
      if (archived != null)
        'archived_at':
            archived ? DateTime.now().toUtc().toIso8601String() : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (patch.length == 1) {
      // Only updated_at would be set — nothing meaningful to change.
      final current = await getDevice(deviceId);
      if (current == null) {
        throw StateError('Device $deviceId not found.');
      }
      return current;
    }
    final row = await _client
        .from('devices')
        .update(patch)
        .eq('id', deviceId)
        .select()
        .single();
    return _mapDeviceRow(Map<String, dynamic>.from(row));
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  Device _mapDeviceRow(Map<String, dynamic> row) {
    final rawTags = row['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return Device(
      id: row['id'] as String,
      hostname: (row['hostname'] as String?) ?? '',
      hostnameLabel: (row['hostname_label'] as String?) ?? '',
      ipAddress: (row['ip_address'] as String?) ?? '',
      macAddress: (row['mac_address'] as String?) ?? '',
      os: (row['os'] as String?) ?? '',
      osVersion: (row['os_version'] as String?) ?? '',
      manufacturer: (row['manufacturer'] as String?) ?? '',
      model: (row['model'] as String?) ?? '',
      assignedUser: (row['assigned_user'] as String?) ?? '',
      location: (row['location'] as String?) ?? '',
      tags: tags,
      status: _parseEnum(
        row['status'],
        DeviceStatus.values,
        DeviceStatus.unknown,
      ),
      health: _parseEnum(
        row['health'],
        HealthStatus.values,
        HealthStatus.unknown,
      ),
      lastSeen: row['last_seen_at'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.parse(row['last_seen_at'] as String),
      uptimeSeconds: (row['uptime_seconds'] as num?)?.toInt() ?? 0,
      archivedAt: row['archived_at'] is String
          ? DateTime.tryParse(row['archived_at'] as String)
          : null,
      serialNumber: (row['serial_number'] as String?) ?? '',
      domain: (row['domain'] as String?) ?? '',
      cpuName: (row['cpu_name'] as String?) ?? '',
      cpuCores: (row['cpu_cores'] as num?)?.toInt() ?? 0,
      architecture: (row['architecture'] as String?) ?? '',
      totalRamGb: (row['total_ram_gb'] as num?)?.toDouble() ?? 0,
      diskTotalGb: (row['disk_total_gb'] as num?)?.toDouble() ?? 0,
      activeWindowTitle: (row['active_window_title'] as String?)?.trim(),
      activeProcessName: (row['active_process_name'] as String?)?.trim(),
      activeWindowSeenAt: row['active_window_seen_at'] is String
          ? DateTime.tryParse(row['active_window_seen_at'] as String)
          : null,
    );
  }

  static T _parseEnum<T extends Enum>(
    Object? raw,
    List<T> values,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }
}
