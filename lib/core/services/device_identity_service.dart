import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Registration state of the current endpoint.
enum DeviceRegistrationState {
  /// First launch on this machine — no Supabase record yet.
  unregistered,

  /// Local UUID minted, registration Edge Function not yet called or
  /// returned an error.
  pending,

  /// Registered successfully; the device_id is known on the server.
  registered,
}

/// Immutable snapshot of what we know about this endpoint locally.
@immutable
class DeviceIdentity {
  final String deviceUuid;
  final DeviceRegistrationState state;
  final DateTime? lastSyncAt;

  const DeviceIdentity({
    required this.deviceUuid,
    required this.state,
    this.lastSyncAt,
  });

  DeviceIdentity copyWith({
    String? deviceUuid,
    DeviceRegistrationState? state,
    DateTime? lastSyncAt,
  }) {
    return DeviceIdentity(
      deviceUuid: deviceUuid ?? this.deviceUuid,
      state: state ?? this.state,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Persists and serves the local device identity.
///
/// * `device_uuid` is stored in BOTH [SharedPreferences] (fast) and
///   [FlutterSecureStorage] (Windows Credential Manager — durable).
///   Prefs act as the cache; secure storage is the source of truth on
///   a mismatch.
/// * Registration state and last-sync timestamp live in prefs only —
///   neither is a secret.
class DeviceIdentityService {
  DeviceIdentityService({
    SharedPreferences? prefs,
    FlutterSecureStorage? secure,
    Uuid? uuid,
  })  : _prefs = prefs,
        _secure = secure ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secure;
  final Uuid _uuid;

  /// In-memory copy of the most recently loaded identity — kept so the
  /// data service can read it synchronously inside write paths.
  DeviceIdentity? _current;
  String? _currentSecret;

  static const _kDeviceUuid = 'device.uuid';
  static const _kRegState = 'device.regState';
  static const _kLastSync = 'device.lastSync';
  static const _kRegSecret = 'device.registrationSecret';

  /// Most recent [DeviceIdentity] returned by [load] / [ensureIdentity].
  DeviceIdentity? get current => _current;

  /// Registration secret issued by the `register-device` Edge Function,
  /// or `null` if the endpoint has not completed registration yet.
  String? get currentRegistrationSecret => _currentSecret;

  /// Lazily-loaded [SharedPreferences] instance.
  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ------------------------------------------------------------------
  // Read
  // ------------------------------------------------------------------

  /// Loads the current identity. Does NOT mint a new UUID on its own —
  /// callers use [ensureIdentity] for that once bootstrap decides the
  /// endpoint is ready to self-provision.
  Future<DeviceIdentity?> load() async {
    final prefs = await _p();

    // Prefer secure storage; fall back to prefs if the DPAPI vault is
    // empty (e.g. during a restore / upgrade migration).
    final secureUuid = await _secure.read(key: _kDeviceUuid);
    final prefsUuid = prefs.getString(_kDeviceUuid);
    final uuid = secureUuid ?? prefsUuid;
    if (uuid == null || uuid.isEmpty) return null;

    // Re-sync the prefs cache if it drifted.
    if (secureUuid != null && prefsUuid != secureUuid) {
      await prefs.setString(_kDeviceUuid, secureUuid);
    }

    final state = _parseState(prefs.getString(_kRegState));
    final lastSyncIso = prefs.getString(_kLastSync);
    final lastSync = (lastSyncIso == null || lastSyncIso.isEmpty)
        ? null
        : DateTime.tryParse(lastSyncIso);

    final identity = DeviceIdentity(
      deviceUuid: uuid,
      state: state,
      lastSyncAt: lastSync,
    );
    _current = identity;
    _currentSecret = await _secure.read(key: _kRegSecret);
    return identity;
  }

  // ------------------------------------------------------------------
  // Write
  // ------------------------------------------------------------------

  /// Returns the current identity, provisioning a fresh v4 UUID on the
  /// first call. Subsequent calls are idempotent.
  Future<DeviceIdentity> ensureIdentity() async {
    final existing = await load();
    if (existing != null) return existing;

    final newUuid = _uuid.v4();
    await _secure.write(key: _kDeviceUuid, value: newUuid);
    final prefs = await _p();
    await prefs.setString(_kDeviceUuid, newUuid);
    await prefs.setString(_kRegState, DeviceRegistrationState.pending.name);

    final identity = DeviceIdentity(
      deviceUuid: newUuid,
      state: DeviceRegistrationState.pending,
    );
    _current = identity;
    return identity;
  }

  /// Persists the `registration_secret` issued by `register-device`.
  /// Stored exclusively in DPAPI-backed secure storage — it is never
  /// written to `SharedPreferences`.
  Future<void> setRegistrationSecret(String secret) async {
    _currentSecret = secret;
    await _secure.write(key: _kRegSecret, value: secret);
  }

  Future<void> markRegistered() async {
    await _setState(DeviceRegistrationState.registered);
    final cur = _current;
    if (cur != null) {
      _current = cur.copyWith(state: DeviceRegistrationState.registered);
    }
  }

  Future<void> markPending() async {
    await _setState(DeviceRegistrationState.pending);
    final cur = _current;
    if (cur != null) {
      _current = cur.copyWith(state: DeviceRegistrationState.pending);
    }
  }

  Future<void> stampSync(DateTime when) async {
    final prefs = await _p();
    await prefs.setString(_kLastSync, when.toIso8601String());
  }

  /// Destructive — only for factory-reset / re-enrolment flows.
  Future<void> clear() async {
    await _secure.delete(key: _kDeviceUuid);
    await _secure.delete(key: _kRegSecret);
    final prefs = await _p();
    await prefs.remove(_kDeviceUuid);
    await prefs.remove(_kRegState);
    await prefs.remove(_kLastSync);
    _current = null;
    _currentSecret = null;
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<void> _setState(DeviceRegistrationState s) async {
    final prefs = await _p();
    await prefs.setString(_kRegState, s.name);
  }

  DeviceRegistrationState _parseState(String? raw) {
    return DeviceRegistrationState.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => DeviceRegistrationState.unregistered,
    );
  }
}
