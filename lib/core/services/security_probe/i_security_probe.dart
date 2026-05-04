import '../../models/security_status.dart';

/// Contract for anything that can produce a live [SecurityStatus]
/// snapshot for the *current* machine.
///
/// Implementations:
///   * [WindowsSecurityProbe] — shell-outs to PowerShell to query
///     Windows Security Center (root\SecurityCenter2 AntiVirusProduct),
///     Get-MpComputerStatus (Defender specifics), Get-NetFirewallProfile
///     (per-profile firewall state), Get-CimInstance on
///     SoftwareLicensingProduct (Windows activation), Get-BitLockerVolume,
///     and vendor-specific registry keys for third-party AV license
///     expiry dates.
///   * [FallbackSecurityProbe] — returns a zero-posture snapshot when
///     the host is not Windows or PowerShell is unavailable, so the UI
///     still paints *something* on first frame.
///
/// The probe is the *sole* source of truth for the Security tab on
/// Device Detail and for the security snapshot uploaded to Supabase.
abstract class ISecurityProbe {
  /// Capture a fresh snapshot synchronously through the OS shell-out.
  /// The returned [SecurityStatus.deviceId] is populated by the caller
  /// (the probe has no knowledge of the device UUID), so subclasses
  /// should leave it as an empty string and let upper layers patch it
  /// in via [SecurityStatus.copyWith].
  Future<SecurityStatus> sample();
}
