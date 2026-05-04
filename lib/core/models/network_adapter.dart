import 'package:flutter/foundation.dart';

enum AdapterType { ethernet, wifi, bluetooth, virtual, loopback, unknown }

AdapterType _parseAdapterType(Object? v) {
  return AdapterType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AdapterType.unknown,
  );
}

/// A single network interface on a device.
@immutable
class NetworkAdapter {
  final String id;
  final String name;
  final AdapterType type;
  final String macAddress;
  final String ipAddress;
  final String subnetMask;
  final String gateway;
  final List<String> dnsServers;
  final bool isConnected;
  final double linkSpeedMbps;
  final int bytesSent;
  final int bytesReceived;

  const NetworkAdapter({
    required this.id,
    required this.name,
    required this.type,
    required this.macAddress,
    required this.ipAddress,
    required this.subnetMask,
    required this.gateway,
    required this.dnsServers,
    required this.isConnected,
    required this.linkSpeedMbps,
    required this.bytesSent,
    required this.bytesReceived,
  });

  NetworkAdapter copyWith({
    String? id,
    String? name,
    AdapterType? type,
    String? macAddress,
    String? ipAddress,
    String? subnetMask,
    String? gateway,
    List<String>? dnsServers,
    bool? isConnected,
    double? linkSpeedMbps,
    int? bytesSent,
    int? bytesReceived,
  }) {
    return NetworkAdapter(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      subnetMask: subnetMask ?? this.subnetMask,
      gateway: gateway ?? this.gateway,
      dnsServers: dnsServers ?? this.dnsServers,
      isConnected: isConnected ?? this.isConnected,
      linkSpeedMbps: linkSpeedMbps ?? this.linkSpeedMbps,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
    );
  }

  factory NetworkAdapter.fromJson(Map<String, dynamic> json) => NetworkAdapter(
        id: json['id'] as String,
        name: json['name'] as String,
        type: _parseAdapterType(json['type']),
        macAddress: json['macAddress'] as String? ?? '',
        ipAddress: json['ipAddress'] as String? ?? '',
        subnetMask: json['subnetMask'] as String? ?? '',
        gateway: json['gateway'] as String? ?? '',
        dnsServers: (json['dnsServers'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        isConnected: json['isConnected'] as bool? ?? false,
        linkSpeedMbps: (json['linkSpeedMbps'] as num?)?.toDouble() ?? 0,
        bytesSent: (json['bytesSent'] as num?)?.toInt() ?? 0,
        bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'macAddress': macAddress,
        'ipAddress': ipAddress,
        'subnetMask': subnetMask,
        'gateway': gateway,
        'dnsServers': dnsServers,
        'isConnected': isConnected,
        'linkSpeedMbps': linkSpeedMbps,
        'bytesSent': bytesSent,
        'bytesReceived': bytesReceived,
      };

  factory NetworkAdapter.mock({
    String id = 'net-001',
    AdapterType type = AdapterType.ethernet,
    bool isConnected = true,
  }) {
    return NetworkAdapter(
      id: id,
      name: type == AdapterType.wifi
          ? 'Intel Wi-Fi 6 AX201'
          : 'Intel Ethernet I219-LM',
      type: type,
      macAddress: 'A4:5E:60:1C:77:02',
      ipAddress: '192.168.1.24',
      subnetMask: '255.255.255.0',
      gateway: '192.168.1.1',
      dnsServers: const ['8.8.8.8', '1.1.1.1'],
      isConnected: isConnected,
      linkSpeedMbps: type == AdapterType.wifi ? 866.7 : 1000.0,
      bytesSent: 245000000,
      bytesReceived: 1820000000,
    );
  }
}
