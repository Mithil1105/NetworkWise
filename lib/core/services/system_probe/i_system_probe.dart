import '../../models/device_hardware_profile.dart';
import '../../models/system_status.dart';

/// Contract for anything that can produce a live [SystemStatus]
/// snapshot for the *current* machine.
///
/// Implementations:
///   * [WindowsSystemProbe] — shell-outs to PowerShell to query
///     Win32_OperatingSystem, Win32_Processor, Win32_LogicalDisk,
///     Get-Counter `\Processor(_Total)\% Processor Time`, etc.
///   * [FallbackSystemProbe] — defensive zero-ish sample used when the
///     host is not Windows or PowerShell is unavailable, so widgets
///     still paint *something* on first frame.
///
/// The probe is the *sole* source of truth for the Dashboard's
/// "System Summary" card and for heartbeat telemetry uploaded to
/// Supabase — there is no more mocking past Phase 13.
abstract class ISystemProbe {
  /// Capture a fresh sample synchronously through the OS shell-out. The
  /// returned [SystemStatus.deviceId] is populated by the caller (the
  /// probe has no knowledge of the device UUID), so subclasses should
  /// leave it as an empty string and let upper layers patch it in via
  /// [SystemStatus.copyWith].
  Future<SystemStatus> sample();

  /// Capture a one-shot hardware inventory (manufacturer, model, serial,
  /// domain, primary MAC + IP, CPU / RAM / disk specs). Used once at
  /// enrolment and opportunistically by the heartbeat loop to keep the
  /// `devices` row in step with the machine's current hardware.
  Future<DeviceHardwareProfile> captureHardwareProfile();
}
