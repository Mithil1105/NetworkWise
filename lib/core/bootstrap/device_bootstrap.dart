import 'dart:io' show Platform;

import '../config/env.dart';
import '../models/device_hardware_profile.dart';
import '../repositories/i_devices_repository.dart';
import '../services/device_identity_service.dart';
import '../services/enrollment_service.dart';
import '../services/system_probe/i_system_probe.dart';

/// Phases the bootstrap flow walks through. The UI splash screen
/// listens to [BootstrapState] and paints a matching message.
enum BootstrapPhase {
  idle,
  resolvingIdentity,
  awaitingEnrollment,
  registering,
  ready,
  failed,
}

class BootstrapState {
  const BootstrapState({
    required this.phase,
    this.organizationId,
    this.deviceUuid,
    this.error,
  });

  final BootstrapPhase phase;
  final String? organizationId;
  final String? deviceUuid;
  final Object? error;

  BootstrapState copyWith({
    BootstrapPhase? phase,
    String? organizationId,
    String? deviceUuid,
    Object? error,
  }) {
    return BootstrapState(
      phase: phase ?? this.phase,
      organizationId: organizationId ?? this.organizationId,
      deviceUuid: deviceUuid ?? this.deviceUuid,
      error: error,
    );
  }

  static const BootstrapState initial =
      BootstrapState(phase: BootstrapPhase.idle);
}

/// Orchestrates the "first-boot after install" sequence:
///
///   1. Ensure a local device UUID exists (`DeviceIdentityService`).
///   2. Resolve the enrollment code — either the one the operator
///      entered on the first-run screen (preferred) or the legacy
///      `APP_ORG_SLUG` fallback from `.env`. If neither is available,
///      pause in the [BootstrapPhase.awaitingEnrollment] state so the
///      splash screen can ask the user for a code.
///   3. If the endpoint is not yet registered, call `register-device`
///      via the repository, persist the returned `registration_secret`
///      to DPAPI, and mark the identity as [DeviceRegistrationState.registered].
///   4. Surface the resolved `organization_id` so the rest of the app
///      (PostgREST header, providers) can start talking to Supabase.
///
/// The bootstrap is designed to be idempotent — callers can re-run
/// [run] as often as they like. It is cheap when everything is already
/// in place.
class DeviceBootstrap {
  DeviceBootstrap({
    required this.identityService,
    required this.devicesRepository,
    required this.enrollmentService,
    required this.systemProbe,
  });

  final DeviceIdentityService identityService;
  final IDevicesRepository devicesRepository;
  final EnrollmentService enrollmentService;
  final ISystemProbe systemProbe;

  Future<BootstrapState> run() async {
    var state = BootstrapState.initial;
    try {
      // 1. Local identity.
      state = state.copyWith(phase: BootstrapPhase.resolvingIdentity);
      final identity = await identityService.ensureIdentity();

      // 2. Registration.
      if (identity.state != DeviceRegistrationState.registered ||
          identityService.currentRegistrationSecret == null) {
        // Resolve which org we attach to — code first, slug as legacy.
        final code = await enrollmentService.read();
        final legacySlug = Env.orgSlug;

        if ((code == null || code.isEmpty) && legacySlug.isEmpty) {
          // First run, no pre-seeded slug — wait for the user to enter
          // their enrollment code via the first-run screen.
          return state.copyWith(
            phase: BootstrapPhase.awaitingEnrollment,
            deviceUuid: identity.deviceUuid,
          );
        }

        state = state.copyWith(phase: BootstrapPhase.registering);

        // Real host info — PowerShell shell-out on Windows, a harmless
        // fallback otherwise.
        final sample = await systemProbe.sample();
        final hostname = sample.hostname.isNotEmpty
            ? sample.hostname
            : _safeHostname();

        // One-shot hardware inventory. Wrapped in a try/catch so that a
        // probe failure doesn't block enrolment — the heartbeat loop
        // will refresh the inventory on a subsequent tick.
        final profile = await _safeHardwareProfile();

        final receipt = await devicesRepository.registerDevice(
          deviceUuid: identity.deviceUuid,
          enrollmentCode: code,
          orgSlug:
              (code == null || code.isEmpty) ? legacySlug : null,
          hostname: hostname,
          os: sample.os.isNotEmpty ? sample.os : _safeOs(),
          osVersion: sample.osBuild.isNotEmpty
              ? sample.osBuild
              : _safeOsVersion(),
          manufacturer: profile.manufacturer,
          model: profile.model,
          macAddress: profile.macAddress,
          ipAddress: profile.ipAddress.isNotEmpty ? profile.ipAddress : null,
          serialNumber:
              profile.serialNumber.isNotEmpty ? profile.serialNumber : null,
          domain: profile.domain.isNotEmpty ? profile.domain : null,
          cpuName: profile.cpuName.isNotEmpty ? profile.cpuName : null,
          cpuCores: profile.cpuCores > 0 ? profile.cpuCores : null,
          architecture:
              profile.architecture.isNotEmpty ? profile.architecture : null,
          totalRamGb: profile.totalRamGb > 0 ? profile.totalRamGb : null,
          diskTotalGb: profile.diskTotalGb > 0 ? profile.diskTotalGb : null,
          environment: Env.environment,
        );

        await identityService.setRegistrationSecret(receipt.registrationSecret);
        await identityService.markRegistered();
        await identityService.stampSync(receipt.enrolledAt);

        state = state.copyWith(
          deviceUuid: receipt.deviceId,
          organizationId: receipt.organizationId,
        );
      } else {
        // Already registered — recover org id on next sync. For now we
        // record only the UUID; the caller will fill organizationId
        // from the first query that returns rows (see note in
        // bootstrap_provider.dart).
        state = state.copyWith(deviceUuid: identity.deviceUuid);
      }

      return state.copyWith(phase: BootstrapPhase.ready);
    } catch (err) {
      return state.copyWith(phase: BootstrapPhase.failed, error: err);
    }
  }

  // ------------------------------------------------------------------
  // Host info — defensive stubs for the OSs without a system probe
  // implementation (macOS dev machines, CI Linux runners).
  // ------------------------------------------------------------------

  String _safeHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'unknown-host';
    }
  }

  String _safeOs() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'windows';
    }
  }

  String _safeOsVersion() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  /// Run the probe's hardware inventory capture — returning
  /// [DeviceHardwareProfile.empty] if the probe throws (e.g. PowerShell
  /// unavailable on a dev Mac). The caller merges these values into the
  /// `register-device` payload; blank fields are simply not forwarded.
  Future<DeviceHardwareProfile> _safeHardwareProfile() async {
    try {
      return await systemProbe.captureHardwareProfile();
    } catch (_) {
      return DeviceHardwareProfile.empty;
    }
  }
}
