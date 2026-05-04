import '../models/security_status.dart';

/// Contract for reading + writing the **security_status** append-only
/// history table, plus the multi-AV inventory and admin license
/// overrides introduced in Phase 18.
///
/// Reads surface the *most recent* row per device (that is what the
/// security screen renders). Writes append a new row via `report-snapshot`.
abstract class ISecurityRepository {
  /// Latest security posture for a device, or `null` if none recorded.
  /// The returned [SecurityStatus.antivirusProducts] list is already
  /// merged with any admin license overrides.
  Future<SecurityStatus?> latestForDevice(String deviceId);

  /// Latest security posture for every device in the org — used by the
  /// fleet security rollup on the dashboard. Returned map is keyed by
  /// `device_id`. Each entry's `antivirusProducts` list carries the
  /// full multi-AV inventory with overrides applied.
  Future<Map<String, SecurityStatus>> latestForAllDevices();

  /// Append a new security snapshot.
  ///
  /// Supabase implementation routes this to the `report-snapshot` Edge
  /// Function together with the adapters payload so the two writes stay
  /// on a single atomic call.
  Future<void> appendSnapshot({
    required String deviceId,
    required String registrationSecret,
    required SecurityStatus snapshot,
  });

  /// Admin: pin (or replace) manual override values against a specific
  /// AV engine on a specific device. Phase 23 — accepts every field the
  /// probe might miss (license expiry, last scan, definitions date,
  /// engine version, custom status, note) so the admin can fill in
  /// whatever the probe couldn't fetch — useful for vendors like
  /// Quick Heal that hide last-scan / definitions behind a cloud
  /// portal. Pass `null` for any field to leave it untouched.
  Future<void> setLicenseOverride({
    required String deviceId,
    required String organizationId,
    required String displayName,
    DateTime? expiresAt,
    String? note,
    DateTime? lastScanAt,
    DateTime? definitionsDate,
    String? customStatus,
    String? engineVersion,
  });

  /// Admin: drop a previously-set override so the probe's own value
  /// wins again on the next snapshot.
  Future<void> clearLicenseOverride({
    required String deviceId,
    required String displayName,
  });
}
