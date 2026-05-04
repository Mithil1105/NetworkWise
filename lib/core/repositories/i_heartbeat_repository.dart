import '../models/device_hardware_profile.dart';
import '../models/system_status.dart';

/// Contract for the high-frequency **heartbeat_logs** append-only table.
///
/// Heartbeats are posted roughly every `heartbeatSeconds` (default 60s)
/// by `HeartbeatLoop`, which pulls a fresh system snapshot from WMI,
/// maps it to a [SystemStatus], and then hands it off to this
/// repository.
abstract class IHeartbeatRepository {
  /// Most recent heartbeat row for a device, or `null` if none yet.
  /// Used by the device detail screen to paint gauges on first paint.
  Future<SystemStatus?> latestForDevice(String deviceId);

  /// Append a new heartbeat. Supabase implementation routes to the
  /// `report-heartbeat` Edge Function so the server can also stamp
  /// `devices.last_seen_at` in the same round-trip.
  ///
  /// [profile] is optional — when supplied the Edge Function will also
  /// refresh `devices.ip_address`, `mac_address`, `hostname`, and the
  /// static hardware inventory. This keeps the fleet list in step with
  /// the endpoint's current LAN address and hardware without a
  /// separate "re-enrol" round-trip.
  Future<void> reportHeartbeat({
    required String deviceId,
    required String registrationSecret,
    required SystemStatus sample,
    DeviceHardwareProfile? profile,
  });
}
