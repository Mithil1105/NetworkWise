import 'dart:async';

import '../../features/devices/data/mock_device_detail.dart';
import '../models/alert.dart';
import '../models/device.dart';
import '../models/network_adapter.dart';
import '../models/security_status.dart';
import '../models/system_status.dart';
import '../repositories/i_alerts_repository.dart';
import '../repositories/i_devices_repository.dart';
import '../repositories/i_heartbeat_repository.dart';
import '../repositories/i_network_adapters_repository.dart';
import '../repositories/i_security_repository.dart';
import 'device_identity_service.dart';
import 'i_data_service.dart';

/// Supabase-backed implementation of [IDataService].
///
/// Keeps an in-memory cache that the synchronous `getDevices` /
/// `getAlerts` / `getDeviceDetail` accessors read from. The cache is
/// primed on [start] and refreshed whenever the Realtime stream for
/// `devices` or `alerts` fires, or whenever a write goes out through
/// this service (optimistic re-fetch).
///
/// Write paths (ack / resolve alert) are delegated to the underlying
/// alerts repository, which in turn calls the `update-alert-status`
/// Edge Function with the current device's registration secret.
class SupabaseDataService implements IDataService {
  SupabaseDataService({
    required IDevicesRepository devicesRepo,
    required IAlertsRepository alertsRepo,
    required ISecurityRepository securityRepo,
    required INetworkAdaptersRepository adaptersRepo,
    required IHeartbeatRepository heartbeatRepo,
    required DeviceIdentityService identityService,
  })  : _devicesRepo = devicesRepo,
        _alertsRepo = alertsRepo,
        _securityRepo = securityRepo,
        _adaptersRepo = adaptersRepo,
        _heartbeatRepo = heartbeatRepo,
        _identity = identityService;

  final IDevicesRepository _devicesRepo;
  final IAlertsRepository _alertsRepo;
  final ISecurityRepository _securityRepo;
  final INetworkAdaptersRepository _adaptersRepo;
  final IHeartbeatRepository _heartbeatRepo;
  final DeviceIdentityService _identity;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  // --------- Cache ---------
  List<Device> _devices = const [];
  List<Alert> _alerts = const [];
  Map<String, SecurityStatus> _security = const {};
  final Map<String, List<NetworkAdapter>> _adapters = <String, List<NetworkAdapter>>{};
  final Map<String, SystemStatus> _heartbeats = <String, SystemStatus>{};

  // --------- Lifecycle ---------
  StreamSubscription<void>? _devicesSub;
  StreamSubscription<void>? _alertsSub;
  Duration _heartbeat = const Duration(seconds: 60);
  Timer? _refreshTimer;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    await _refreshSnapshot();

    _devicesSub = _devicesRepo.watchDevices().listen((_) => _refreshDevices());
    _alertsSub = _alertsRepo.watchAlerts().listen((_) => _refreshAlerts());

    _armRefreshTimer();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _devicesSub?.cancel();
    await _alertsSub?.cancel();
    if (!_changes.isClosed) await _changes.close();
  }

  // --------- Snapshot accessors ---------

  @override
  List<Device> getDevices() => List<Device>.unmodifiable(_devices);

  @override
  List<Alert> getAlerts() => List<Alert>.unmodifiable(_alerts);

  @override
  MockDeviceDetail getDeviceDetail(String deviceId) {
    // If the cache doesn't have it yet we fall back to the deterministic
    // mock so the UI still paints during the first round-trip.
    final device = _devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => Device.mock(id: deviceId),
    );
    final cached = _heartbeats[deviceId];
    final security = _security[deviceId];
    final adapters = _adapters[deviceId] ?? const <NetworkAdapter>[];
    final alertHistory =
        _alerts.where((a) => a.deviceId == deviceId).toList(growable: false);

    // Kick off a lazy fetch for the latest heartbeat + adapters the
    // first time this device is opened. The result lands in the caches
    // and a change-tick re-paints the screen with live telemetry.
    if (!_heartbeats.containsKey(deviceId)) {
      unawaited(_hydrateDeviceDetail(deviceId));
    }

    // Heartbeat carries the *dynamic* telemetry (CPU %, used RAM, used
    // disk, battery). The static hardware inventory (cpu name/cores,
    // architecture, total RAM, total disk) is carried on the Device
    // row itself — so we merge the two sources here. That way the
    // Device Detail screen shows real manufacturer / model / CPU even
    // before the first heartbeat has landed.
    final system = (cached ?? _zeroSystem(deviceId, device)).copyWith(
      hostname: device.displayName,
      os: device.os,
      architecture:
          cached?.architecture.isNotEmpty == true
              ? cached!.architecture
              : (device.architecture.isNotEmpty ? device.architecture : 'x64'),
      cpuName: cached?.cpuName.isNotEmpty == true
          ? cached!.cpuName
          : device.cpuName,
      cpuCores: (cached?.cpuCores ?? 0) > 0 ? cached!.cpuCores : device.cpuCores,
      totalRamGb: (cached?.totalRamGb ?? 0) > 0
          ? cached!.totalRamGb
          : device.totalRamGb,
      diskTotalGb: (cached?.diskTotalGb ?? 0) > 0
          ? cached!.diskTotalGb
          : device.diskTotalGb,
    );

    return MockDeviceDetail(
      system: system,
      security: security ?? SecurityStatus.mock(deviceId: deviceId),
      adapters: adapters,
      alertHistory: alertHistory,
      serialNumber:
          device.serialNumber.isNotEmpty ? device.serialNumber : 'N/A',
      domain: device.domain,
      enrolledAt: device.lastSeen,
      tags: List<String>.unmodifiable(device.tags),
    );
  }

  /// First-paint fallback SystemStatus built from the Device row's
  /// static hardware inventory. Gauges (%) start at zero until the
  /// real heartbeat lands.
  SystemStatus _zeroSystem(String deviceId, Device device) => SystemStatus(
        deviceId: deviceId,
        hostname: device.displayName,
        os: device.os,
        osBuild: device.osVersion,
        architecture:
            device.architecture.isNotEmpty ? device.architecture : 'x64',
        cpuName: device.cpuName,
        cpuCores: device.cpuCores,
        cpuUsagePercent: 0,
        totalRamGb: device.totalRamGb,
        usedRamGb: 0,
        diskTotalGb: device.diskTotalGb,
        diskUsedGb: 0,
        uptimeSeconds: device.uptimeSeconds,
        batteryPercent: null,
        isCharging: null,
        timestamp: device.lastSeen,
      );

  /// Pull the latest heartbeat + adapter list for [deviceId] and emit a
  /// change-tick when either lands. Marked in [_heartbeats] with a
  /// sentinel so we don't re-fetch on every rebuild — a real refresh
  /// happens via the periodic timer / realtime subscription.
  Future<void> _hydrateDeviceDetail(String deviceId) async {
    // Sentinel: stamp an empty heartbeat so `containsKey` returns true
    // on subsequent reads before the fetch completes.
    _heartbeats[deviceId] = _heartbeats[deviceId] ?? _placeholderSystem(deviceId);
    try {
      final latest = await _heartbeatRepo.latestForDevice(deviceId);
      if (latest != null) {
        _heartbeats[deviceId] = latest;
      }
    } catch (_) {/* keep placeholder */}
    try {
      final list = await _adaptersRepo.listForDevice(deviceId);
      _adapters[deviceId] = list;
    } catch (_) {/* keep empty list */}
    _emit();
  }

  SystemStatus _placeholderSystem(String deviceId) => SystemStatus(
        deviceId: deviceId,
        hostname: '',
        os: '',
        osBuild: '',
        architecture: '',
        cpuName: '',
        cpuCores: 0,
        cpuUsagePercent: 0,
        totalRamGb: 0,
        usedRamGb: 0,
        diskTotalGb: 0,
        diskUsedGb: 0,
        uptimeSeconds: 0,
        batteryPercent: null,
        isCharging: null,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  // --------- Mutations ---------

  @override
  Future<void> acknowledgeAlert(String alertId) async {
    final id = _identity.current;
    if (id == null) return;
    final secret = _identity.currentRegistrationSecret;
    if (secret == null) return;
    await _alertsRepo.acknowledgeAlert(
      deviceId: id.deviceUuid,
      registrationSecret: secret,
      alertId: alertId,
    );
    await _refreshAlerts();
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    final id = _identity.current;
    if (id == null) return;
    final secret = _identity.currentRegistrationSecret;
    if (secret == null) return;
    await _alertsRepo.resolveAlert(
      deviceId: id.deviceUuid,
      registrationSecret: secret,
      alertId: alertId,
    );
    await _refreshAlerts();
  }

  @override
  void configureHeartbeat(Duration interval) {
    if (_disposed) return;
    final clampedSeconds = interval.inSeconds.clamp(5, 3600);
    final next = Duration(seconds: clampedSeconds);
    if (next == _heartbeat && _refreshTimer != null) return;
    _heartbeat = next;
    _armRefreshTimer();
  }

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    // Clear the per-device heartbeat / adapter caches so the detail
    // screen re-hydrates from the latest rows on the next `getDeviceDetail`.
    _heartbeats.clear();
    _adapters.clear();
    await _refreshSnapshot();
  }

  // --------- Internals ---------

  void _armRefreshTimer() {
    _refreshTimer?.cancel();
    if (_disposed || !_started) return;
    _refreshTimer = Timer.periodic(_heartbeat, (_) => _refreshDevices());
  }

  Future<void> _refreshSnapshot() async {
    await Future.wait<void>(<Future<void>>[
      _refreshDevices(emit: false),
      _refreshAlerts(emit: false),
      _refreshSecurity(emit: false),
    ]);
    _emit();
  }

  Future<void> _refreshDevices({bool emit = true}) async {
    try {
      _devices = await _devicesRepo.listDevices();
    } catch (_) {
      // Swallow — UI keeps showing the last-known snapshot.
    }
    if (emit) _emit();
  }

  Future<void> _refreshAlerts({bool emit = true}) async {
    try {
      _alerts = await _alertsRepo.listAlerts();
    } catch (_) {/* keep last snapshot */}
    if (emit) _emit();
  }

  Future<void> _refreshSecurity({bool emit = true}) async {
    try {
      _security = await _securityRepo.latestForAllDevices();
    } catch (_) {/* keep last snapshot */}
    if (emit) _emit();
  }

  void _emit() {
    if (_disposed || _changes.isClosed) return;
    _changes.add(null);
  }
}
