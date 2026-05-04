import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/network_adapter.dart';
import '../i_network_adapters_repository.dart';

/// Supabase-backed implementation of [INetworkAdaptersRepository].
///
/// Reads come from PostgREST (scoped by RLS); the write path is
/// delegated to the `report-snapshot` Edge Function which performs a
/// delete-all-then-insert atomically.
class SupabaseNetworkAdaptersRepository
    implements INetworkAdaptersRepository {
  SupabaseNetworkAdaptersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NetworkAdapter>> listForDevice(String deviceId) async {
    final rows = await _client
        .from('network_adapters')
        .select()
        .eq('device_id', deviceId)
        .order('observed_at', ascending: false);
    return rows
        .map((r) => _mapRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> replaceAdaptersForDevice({
    required String deviceId,
    required String registrationSecret,
    required List<NetworkAdapter> adapters,
  }) async {
    // Note: this repository is used in concert with
    // `SupabaseSecurityRepository.appendSnapshot` via the higher-level
    // `SupabaseDataService.submitSnapshot(...)` which calls a SINGLE
    // Edge Function (`report-snapshot`) for both pieces. We still keep
    // this method callable in isolation for tests and the sync queue.
    final body = <String, dynamic>{
      'device_id': deviceId,
      'registration_secret': registrationSecret,
      'adapters': adapters.map(_toSnapshotJson).toList(growable: false),
      // Empty security payload — server keeps whatever the latest row
      // is if the object is empty.
      'security': <String, dynamic>{},
    };
    final response =
        await _client.functions.invoke('report-snapshot', body: body);
    _throwIfFailed(response, 'report-snapshot');
  }

  // ------------------------------------------------------------------
  // Mapping
  // ------------------------------------------------------------------

  NetworkAdapter _mapRow(Map<String, dynamic> row) {
    return NetworkAdapter(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      type: _parseAdapter(row['type']),
      macAddress: (row['mac_address'] as String?) ?? '',
      ipAddress: (row['ip_address'] as String?) ?? '',
      subnetMask: (row['subnet_mask'] as String?) ?? '',
      gateway: (row['gateway'] as String?) ?? '',
      dnsServers: ((row['dns_servers'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      isConnected: (row['is_connected'] as bool?) ?? false,
      linkSpeedMbps: (row['link_speed_mbps'] as num?)?.toDouble() ?? 0,
      bytesSent: (row['bytes_sent'] as num?)?.toInt() ?? 0,
      bytesReceived: (row['bytes_received'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _toSnapshotJson(NetworkAdapter a) {
    // Map to the shape expected by `report-snapshot` (see its header
    // comment in supabase/functions/report-snapshot/index.ts).
    final type = switch (a.type) {
      AdapterType.ethernet => 'ethernet',
      AdapterType.wifi => 'wifi',
      AdapterType.virtual => 'virtual',
      AdapterType.bluetooth => 'unknown',
      AdapterType.loopback => 'unknown',
      AdapterType.unknown => 'unknown',
    };
    return <String, dynamic>{
      'name': a.name,
      'type': type,
      'mac_address': a.macAddress,
      'ip_address': a.ipAddress,
      'subnet_mask': a.subnetMask,
      'gateway': a.gateway,
      'dns_servers': a.dnsServers,
      'is_connected': a.isConnected,
      'link_speed_mbps': a.linkSpeedMbps,
      'bytes_sent': a.bytesSent,
      'bytes_received': a.bytesReceived,
    };
  }

  AdapterType _parseAdapter(Object? raw) {
    if (raw is! String) return AdapterType.unknown;
    switch (raw) {
      case 'ethernet':
        return AdapterType.ethernet;
      case 'wifi':
        return AdapterType.wifi;
      case 'virtual':
        return AdapterType.virtual;
      case 'cellular':
        return AdapterType.unknown;
      default:
        return AdapterType.unknown;
    }
  }

  void _throwIfFailed(FunctionResponse r, String name) {
    if (r.status != null && r.status! >= 400) {
      throw StateError('$name failed (${r.status}): ${r.data}');
    }
  }
}
