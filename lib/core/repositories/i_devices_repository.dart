import '../models/device.dart';

/// Receipt returned by [IDevicesRepository.registerDevice].
class DeviceRegistrationReceipt {
  const DeviceRegistrationReceipt({
    required this.deviceId,
    required this.organizationId,
    required this.registrationSecret,
    required this.enrolledAt,
  });

  final String deviceId;
  final String organizationId;
  final String registrationSecret;
  final DateTime enrolledAt;
}

/// Contract for reading + writing the **devices** table.
///
/// The app supports two implementations:
///   * [MockDevicesRepository]     — in-memory seed data, used for UI preview
///     and offline development.
///   * [SupabaseDevicesRepository] — real backend backed by the `devices`
///     Postgres table through PostgREST.
///
/// All write operations that mutate the authoritative record are executed
/// via an Edge Function (because the Flutter client only holds the anon
/// key). Therefore repository writers return `Future<void>` and throw on
/// failure rather than surfacing PostgREST error objects.
abstract class IDevicesRepository {
  /// List every device the current caller is allowed to see. For the
  /// Flutter app this is scoped by the `x-org-id` request header.
  Future<List<Device>> listDevices();

  /// Stream of the devices table. Supabase implementation subscribes to
  /// Postgres Changes; the Mock implementation relays the broadcast from
  /// its internal `StreamController<void>`.
  ///
  /// Consumers should re-read via [listDevices] on every event.
  Stream<void> watchDevices();

  /// Fetch a single device by its UUID, or `null` if not found.
  Future<Device?> getDevice(String deviceId);

  /// Register or rotate this endpoint's device row.
  ///
  /// Calls the `register-device` Edge Function with EITHER:
  ///   * `enrollment_code` — the rolling code the operator types into
  ///     the first-run screen (preferred), OR
  ///   * `org_slug` — legacy path that ships with `.env APP_ORG_SLUG`
  ///     baked into the installer.
  ///
  /// Plus the usual host metadata — `hostname`, `os`, `os_version`,
  /// `manufacturer`, `model`, `mac_address` etc. from the local WMI /
  /// PowerShell probe.
  ///
  /// Returns a [DeviceRegistrationReceipt] carrying the server-issued
  /// `registration_secret` (persist immediately via
  /// `DeviceIdentityService.setRegistrationSecret`) plus the
  /// `organization_id` the endpoint has been attached to.
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
  });

  /// Convenience writes that keep denormalized fields in sync. These are
  /// OK to call directly because they do not touch the registration
  /// secret — the backend will reject any writer that is not the
  /// service-role Edge Function via RLS.
  Future<void> touchLastSeen(String deviceId);

  /// Admin-only patch. RLS policy `devices_admin_update` gates this on
  /// the Supabase side — an endpoint with only the anon key will see a
  /// `row-level security violation` error.
  ///
  /// Pass `null` (or omit) for any field that should stay unchanged;
  /// pass an empty string to clear a text field. [tags] is **replaced**
  /// wholesale when provided. Set [archived] to `true` to stamp
  /// `archived_at = now()`, or `false` to clear it.
  Future<Device> updateDevice({
    required String deviceId,
    String? hostnameLabel,
    String? assignedUser,
    String? location,
    List<String>? tags,
    bool? archived,
  });
}
