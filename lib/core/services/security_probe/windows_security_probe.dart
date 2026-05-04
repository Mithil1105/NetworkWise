import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/antivirus_product.dart';
import '../../models/security_status.dart';
import 'i_security_probe.dart';

/// Real implementation of [ISecurityProbe] for Windows.
///
/// Shells out to a single consolidated PowerShell script that pulls:
///   * All registered AV products from `root\SecurityCenter2`. WSC
///     exposes ANY AV vendor that registers with the OS — Defender,
///     Kaspersky, Quick Heal, Bitdefender, Norton, McAfee, ESET, Avast
///     — so the caller gets a full inventory, not just the primary.
///   * Defender specifics via `Get-MpComputerStatus` (engine version,
///     last scan, real-time protection, signatures age).
///   * Per-profile firewall state via `Get-NetFirewallProfile`.
///   * Windows activation state via `SoftwareLicensingProduct` (matches
///     the Windows edition row).
///   * BitLocker status for the system volume via `Get-BitLockerVolume`.
///   * Vendor-specific license expiry via well-known registry paths
///     for common third-party AVs — these surface a `LicenseExpiry`
///     string under HKLM that the probe best-effort parses into an
///     ISO 8601 timestamp.
///
/// Each block is wrapped in `try/catch` so a locked-down endpoint with
/// partial WMI access still produces a usable snapshot — missing data
/// just surfaces as `false` / `null` / `'unknown'` in the returned
/// [SecurityStatus].
class WindowsSecurityProbe implements ISecurityProbe {
  WindowsSecurityProbe({
    this.powershellExecutable = 'powershell.exe',
    this.timeout = const Duration(seconds: 15),
  });

  /// Path (or command name) of `powershell.exe`. Overridable so golden
  /// tests can swap in a script that returns a fixture payload.
  final String powershellExecutable;

  /// Upper bound for the shell-out. WSC queries are normally sub-second
  /// but on freshly-imaged machines with heavy AV loaders 5–10s is
  /// possible — we allow 15s before giving up.
  final Duration timeout;

  @override
  Future<SecurityStatus> sample() async {
    if (!Platform.isWindows) {
      return _fallback();
    }
    try {
      final result = await Process.run(
        powershellExecutable,
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          _script,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      if (result.exitCode != 0) return _fallback();
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) return _fallback();
      final decoded = jsonDecode(stdout);
      if (decoded is! Map<String, dynamic>) return _fallback();
      return _fromJson(decoded);
    } on TimeoutException {
      return _fallback();
    } catch (_) {
      return _fallback();
    }
  }

  SecurityStatus _fallback() => const SecurityStatus(
        deviceId: '',
        antivirusName: 'Unknown',
        antivirusEnabled: false,
        antivirusUpToDate: false,
        realTimeProtection: false,
        lastScanAt: null,
        firewallDomain: FirewallState.unknown,
        firewallPrivate: FirewallState.unknown,
        firewallPublic: FirewallState.unknown,
        windowsActivated: false,
        bitLockerEnabled: false,
        lastUpdateCheck: null,
        antivirusProducts: <AntivirusProduct>[],
      );

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  SecurityStatus _fromJson(Map<String, dynamic> j) {
    final productsRaw = j['antivirus_products'];
    final products = <AntivirusProduct>[];
    if (productsRaw is List) {
      for (final p in productsRaw) {
        if (p is! Map) continue;
        final m = Map<String, dynamic>.from(p);
        products.add(AntivirusProduct(
          displayName: _asString(m['display_name'], fallback: 'Unknown AV'),
          productId: _asString(m['product_id'], fallback: ''),
          isPrimary: _asBool(m['is_primary']),
          isEnabled: _asBool(m['is_enabled']),
          isUpToDate: _asBool(m['is_up_to_date']),
          realTimeProtection: _asBool(m['real_time_protection']),
          lastScanAt: _asDateOrNull(m['last_scan_at']),
          licenseExpiresAt: _asDateOrNull(m['license_expires_at']),
          licenseSource: m['license_source'] == null
              ? AntivirusLicenseSource.unknown
              : AntivirusLicenseSource.values.firstWhere(
                  (e) => e.name == m['license_source'].toString(),
                  orElse: () => AntivirusLicenseSource.unknown,
                ),
        ));
      }
    }

    // Pick the primary AV to populate the legacy single-AV fields so
    // existing widgets keep painting without knowing about the list.
    final primary = products.firstWhere(
      (p) => p.isPrimary,
      orElse: () => products.isEmpty
          ? const AntivirusProduct(
              displayName: 'Unknown',
              productId: '',
              isPrimary: false,
              isEnabled: false,
              isUpToDate: false,
              realTimeProtection: false,
              lastScanAt: null,
              licenseExpiresAt: null,
              licenseSource: AntivirusLicenseSource.unknown,
            )
          : products.first,
    );

    return SecurityStatus(
      deviceId: '',
      antivirusName: primary.displayName,
      antivirusEnabled: primary.isEnabled,
      antivirusUpToDate: primary.isUpToDate,
      realTimeProtection: primary.realTimeProtection,
      lastScanAt: primary.lastScanAt,
      firewallDomain: _asFirewall(j['firewall_domain']),
      firewallPrivate: _asFirewall(j['firewall_private']),
      firewallPublic: _asFirewall(j['firewall_public']),
      windowsActivated: _asBool(j['windows_activated']),
      bitLockerEnabled: _asBool(j['bitlocker_enabled']),
      lastUpdateCheck: _asDateOrNull(j['last_update_check']),
      antivirusProducts: List<AntivirusProduct>.unmodifiable(products),
    );
  }

  static String _asString(Object? v, {required String fallback}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static bool _asBool(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final lower = v.toLowerCase().trim();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  static DateTime? _asDateOrNull(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    return parsed?.toUtc();
  }

  static FirewallState _asFirewall(Object? v) {
    final s = v?.toString().toLowerCase().trim();
    if (s == 'enabled') return FirewallState.enabled;
    if (s == 'disabled') return FirewallState.disabled;
    return FirewallState.unknown;
  }

  // ---------------------------------------------------------------------------
  // PowerShell script
  // ---------------------------------------------------------------------------
  //
  // One consolidated script so we pay the PowerShell startup cost once
  // per probe. Every block is wrapped in TryGet so a single failed
  // query never wedges the overall sample.
  //
  static const String _script = r'''
$ErrorActionPreference = 'SilentlyContinue'

function TryGet {
  param([scriptblock]$Block)
  try { & $Block } catch { $null }
}

# --- Windows Security Center (ANY registered AV vendor) ---------------------
# WSC's AntiVirusProduct exposes all AVs the OS is aware of — Defender,
# Kaspersky, Quick Heal, Bitdefender, Norton, McAfee, ESET, Avast, …
# productState is a bitmask encoded as a 32-bit integer: bits 0x1000
# and 0x2000 in byte 3 denote "enabled" + "up-to-date" respectively.
$wscProducts = TryGet {
  Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct
}

function Decode-WscState {
  param([int]$state)
  # Byte layout (from MSDN forums): high byte = on/off, mid = sig date.
  $hex = '{0:X6}' -f $state
  $enabledByte = [Convert]::ToInt32($hex.Substring(0,2), 16)
  $sigByte     = [Convert]::ToInt32($hex.Substring(2,2), 16)
  $enabled     = ($enabledByte -band 0x10) -ne 0
  $upToDate    = $sigByte -eq 0x00
  return @{ enabled = $enabled; upToDate = $upToDate }
}

# --- Defender specifics ----------------------------------------------------
$mp = TryGet { Get-MpComputerStatus }

# --- Vendor registry scan for license expiry ------------------------------
# Best-effort: check well-known paths for third-party AVs that stash a
# license expiry string in HKLM. We return a hashtable keyed by a
# normalised vendor name so the mapping step can match on WSC's
# displayName.
$licenseHints = @{}

$vendorPaths = @(
  # Kaspersky Lab (most SKUs) — LicDaysLeft is an int, converted later
  @{ Vendor = 'Kaspersky'; Path = 'HKLM:\SOFTWARE\KasperskyLab\protected\AVP*\settings'; ValueName = 'LicDaysLeft' },
  # Quick Heal — known to vary by SKU and 32-vs-64 install. Try every
  # well-known sub-key including the WOW6432Node mirror.
  @{ Vendor = 'Quick Heal'; Path = 'HKLM:\SOFTWARE\Quick Heal\Quick Heal Total Security\Misc'; ValueName = 'ExpiryDate' },
  @{ Vendor = 'Quick Heal'; Path = 'HKLM:\SOFTWARE\Quick Heal\Quick Heal AntiVirus Pro\Misc'; ValueName = 'ExpiryDate' },
  @{ Vendor = 'Quick Heal'; Path = 'HKLM:\SOFTWARE\Quick Heal\Quick Heal Internet Security\Misc'; ValueName = 'ExpiryDate' },
  @{ Vendor = 'Quick Heal'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Quick Heal\*\Misc'; ValueName = 'ExpiryDate' },
  @{ Vendor = 'Quick Heal'; Path = 'HKLM:\SOFTWARE\Quick Heal\*\Setup'; ValueName = 'ExpiryDate' },
  # Bitdefender
  @{ Vendor = 'Bitdefender'; Path = 'HKLM:\SOFTWARE\Bitdefender\*'; ValueName = 'LicenseExpiry' },
  @{ Vendor = 'Bitdefender'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Bitdefender\*'; ValueName = 'LicenseExpiry' },
  # Norton / Symantec
  @{ Vendor = 'Norton'; Path = 'HKLM:\SOFTWARE\Symantec\*'; ValueName = 'LicenseEndDate' },
  @{ Vendor = 'Norton'; Path = 'HKLM:\SOFTWARE\Norton\*'; ValueName = 'LicenseEndDate' },
  @{ Vendor = 'Norton'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Norton\*'; ValueName = 'LicenseEndDate' },
  # McAfee
  @{ Vendor = 'McAfee'; Path = 'HKLM:\SOFTWARE\McAfee\*'; ValueName = 'LicenseExpiry' },
  @{ Vendor = 'McAfee'; Path = 'HKLM:\SOFTWARE\WOW6432Node\McAfee\*'; ValueName = 'LicenseExpiry' }
)

foreach ($v in $vendorPaths) {
  TryGet {
    Get-ItemProperty -Path $v.Path -Name $v.ValueName -ErrorAction SilentlyContinue |
      ForEach-Object {
        $raw = $_.($v.ValueName)
        if ($raw) {
          $iso = $null
          # LicDaysLeft is an int day count, not a date — convert.
          if ($v.ValueName -eq 'LicDaysLeft' -and $raw -match '^\d+$') {
            $iso = (Get-Date).AddDays([int]$raw).ToUniversalTime().ToString('o')
          } else {
            $parsed = Get-Date $raw -ErrorAction SilentlyContinue
            if ($parsed) { $iso = $parsed.ToUniversalTime().ToString('o') }
          }
          if ($iso) { $licenseHints[$v.Vendor] = $iso }
        }
      }
  } | Out-Null
}

# --- Build the antivirus_products list --------------------------------------
$avList = @()
if ($wscProducts) {
  foreach ($p in $wscProducts) {
    $state = Decode-WscState -state $p.productState
    $name  = $p.displayName

    # Find a license hint by loose vendor-name match.
    $licenseIso = $null
    $licenseSrc = 'unknown'
    foreach ($k in $licenseHints.Keys) {
      if ($name -match [regex]::Escape($k)) {
        $licenseIso = $licenseHints[$k]
        $licenseSrc = 'registry'
        break
      }
    }

    # Defender is free, so suppress any stray license hint for it.
    $lastScan = $null
    $rtp      = $state.enabled
    if ($name -match 'Defender' -and $mp) {
      $rtp      = [bool]$mp.RealTimeProtectionEnabled
      if ($mp.QuickScanEndTime) {
        $lastScan = ([datetime]$mp.QuickScanEndTime).ToUniversalTime().ToString('o')
      } elseif ($mp.FullScanEndTime) {
        $lastScan = ([datetime]$mp.FullScanEndTime).ToUniversalTime().ToString('o')
      }
      $licenseIso = $null
      $licenseSrc = 'unknown'
    }

    # Mark primary by matching against Defender if present and enabled,
    # otherwise the first enabled product wins.
    $isPrimary = $false
    if ($name -match 'Defender' -and $state.enabled) { $isPrimary = $true }

    $avList += [ordered]@{
      display_name         = $name
      product_id           = $p.instanceGuid
      is_primary           = $isPrimary
      is_enabled           = $state.enabled
      is_up_to_date        = $state.upToDate
      real_time_protection = $rtp
      last_scan_at         = $lastScan
      license_expires_at   = $licenseIso
      license_source       = $licenseSrc
    }
  }
  # Fallback: if nobody got flagged primary (non-Defender stack), mark
  # the first enabled one as primary so the UI has something to show.
  if (-not ($avList | Where-Object { $_.is_primary })) {
    $firstEnabled = $avList | Where-Object { $_.is_enabled } | Select-Object -First 1
    if ($firstEnabled) { $firstEnabled.is_primary = $true }
  }
}

# --- Firewall per profile ---------------------------------------------------
function Fw-State {
  param([string]$profile)
  $p = TryGet { Get-NetFirewallProfile -Profile $profile }
  if (-not $p) { return 'unknown' }
  if ($p.Enabled) { return 'enabled' }
  return 'disabled'
}
$fwDomain  = Fw-State 'Domain'
$fwPrivate = Fw-State 'Private'
$fwPublic  = Fw-State 'Public'

# --- Windows activation -----------------------------------------------------
$slp = TryGet {
  Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" |
    Select-Object -First 1
}
$activated = $false
if ($slp) {
  # LicenseStatus: 1 = Licensed.
  $activated = ($slp.LicenseStatus -eq 1)
}

# --- BitLocker (system volume) ---------------------------------------------
$sys = TryGet {
  Get-BitLockerVolume -MountPoint $env:SystemDrive
}
$bl = $false
if ($sys) {
  $bl = ($sys.ProtectionStatus -eq 1)
}

# --- Last Windows Update check --------------------------------------------
$lastUpdate = TryGet {
  (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect' -ErrorAction SilentlyContinue).LastSuccessTime
}
$lastUpdateIso = $null
if ($lastUpdate) {
  $parsed = Get-Date $lastUpdate -ErrorAction SilentlyContinue
  if ($parsed) { $lastUpdateIso = $parsed.ToUniversalTime().ToString('o') }
}

# --- Emit -------------------------------------------------------------------
$result = [ordered]@{
  antivirus_products = $avList
  firewall_domain    = $fwDomain
  firewall_private   = $fwPrivate
  firewall_public    = $fwPublic
  windows_activated  = $activated
  bitlocker_enabled  = $bl
  last_update_check  = $lastUpdateIso
}

$result | ConvertTo-Json -Depth 5 -Compress
''';
}
