import 'package:flutter/foundation.dart';

/// Static hardware inventory captured once at enrolment (and refreshed
/// opportunistically by the heartbeat loop). Unlike [SystemStatus],
/// which is a per-tick telemetry sample, a [DeviceHardwareProfile]
/// changes only when the hardware itself changes — RAM module swap,
/// primary disk replacement, CPU upgrade, domain join.
///
/// The probe produces this value synchronously on demand; the bootstrap
/// path forwards it to the `register-device` Edge Function so the
/// `devices` table carries a current inventory without having to JOIN
/// against `heartbeat_logs` on every detail render.
@immutable
class DeviceHardwareProfile {
  final String manufacturer;
  final String model;
  final String serialNumber;
  final String domain;
  final String macAddress;
  final String ipAddress;
  final String cpuName;
  final int cpuCores;
  final String architecture;
  final double totalRamGb;
  final double diskTotalGb;

  const DeviceHardwareProfile({
    required this.manufacturer,
    required this.model,
    required this.serialNumber,
    required this.domain,
    required this.macAddress,
    required this.ipAddress,
    required this.cpuName,
    required this.cpuCores,
    required this.architecture,
    required this.totalRamGb,
    required this.diskTotalGb,
  });

  static const DeviceHardwareProfile empty = DeviceHardwareProfile(
    manufacturer: '',
    model: '',
    serialNumber: '',
    domain: '',
    macAddress: '',
    ipAddress: '',
    cpuName: '',
    cpuCores: 0,
    architecture: '',
    totalRamGb: 0,
    diskTotalGb: 0,
  );

  Map<String, dynamic> toJson() => {
        'manufacturer': manufacturer,
        'model': model,
        'serial_number': serialNumber,
        'domain': domain,
        'mac_address': macAddress,
        'ip_address': ipAddress,
        'cpu_name': cpuName,
        'cpu_cores': cpuCores,
        'architecture': architecture,
        'total_ram_gb': totalRamGb,
        'disk_total_gb': diskTotalGb,
      };
}
