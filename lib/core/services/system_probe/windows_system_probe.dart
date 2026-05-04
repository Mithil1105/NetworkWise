import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/device_hardware_profile.dart';
import '../../models/disk_volume.dart';
import '../../models/system_status.dart';
import 'i_system_probe.dart';

/// Live Windows probe — shells out to `powershell.exe` with a single
/// composite script that returns one JSON blob covering OS, CPU,
/// memory, disk and battery. One process per sample keeps the cost low
/// (< 200 ms on a warm cache) and avoids threading a long-lived
/// PowerShell runspace from Dart.
///
/// The script is deliberately tolerant — any individual CIM query that
/// throws is swallowed, and the corresponding field is returned as
/// `null`. That way the Dashboard never falls over because a single
/// counter is unavailable (e.g. `Win32_Battery` on a desktop).
class WindowsSystemProbe implements ISystemProbe {
  WindowsSystemProbe({
    this.powershellExecutable = 'powershell.exe',
    this.timeout = const Duration(seconds: 8),
  });

  /// Path to the PowerShell 5.1 executable. On the vast majority of
  /// Windows 10 / 11 installs this resolves to
  /// `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
  /// via %PATH%. Overridable for tests and for shops that want to
  /// pin `pwsh.exe` (PowerShell 7).
  final String powershellExecutable;

  /// Wall-clock timeout for a single sample. If a broken WMI provider
  /// hangs, we don't want the heartbeat loop to hang with it.
  final Duration timeout;

  static const String _script = r'''
$ErrorActionPreference = 'SilentlyContinue'

function TryGet {
  param([scriptblock]$Block)
  try { & $Block } catch { $null }
}

$os       = TryGet { Get-CimInstance -ClassName Win32_OperatingSystem }
$cpu      = TryGet { Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 }
# Aggregate across every fixed volume (DriveType=3). A workstation with
# a C:\ system drive plus one or more D:\ / E:\ data drives should see
# the total usable storage, not just the boot volume.
$disks    = TryGet { @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3") }
$diskTotalBytes = 0
$diskFreeBytes  = 0
$diskCount      = 0
$diskList = @()
if ($disks) {
  foreach ($d in $disks) {
    $sizeBytes = if ($d.Size) { [double]$d.Size } else { 0 }
    $freeBytes = if ($d.FreeSpace) { [double]$d.FreeSpace } else { 0 }
    if ($sizeBytes -gt 0) { $diskTotalBytes += $sizeBytes }
    if ($freeBytes -gt 0) { $diskFreeBytes += $freeBytes }
    $diskCount++
    $diskList += [PSCustomObject]@{
      drive       = if ($d.DeviceID) { [string]$d.DeviceID } else { '' }
      total_gb    = if ($sizeBytes -gt 0) { [math]::Round($sizeBytes / 1GB, 1) } else { 0 }
      free_gb     = if ($sizeBytes -gt 0) { [math]::Round($freeBytes / 1GB, 1) } else { 0 }
      label       = if ($d.VolumeName) { [string]$d.VolumeName } else { '' }
      file_system = if ($d.FileSystem) { [string]$d.FileSystem } else { '' }
    }
  }
}
$battery  = TryGet { Get-CimInstance -ClassName Win32_Battery | Select-Object -First 1 }
$computer = TryGet { Get-CimInstance -ClassName Win32_ComputerSystem }

# Instantaneous CPU% — one quick sample of the Processor performance
# counter. The $NULL redirect is there because the cmdlet is chatty on
# first run. Fail silently on hosts without the counter registered.
$cpuPercent = $null
try {
  $counter = Get-Counter -Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
  $cpuPercent = [math]::Round($counter.CounterSamples[0].CookedValue, 1)
} catch {
  # Fall back to a CIM-level load average — less responsive but always
  # available inside restricted domains.
  if ($cpu) { $cpuPercent = [double]$cpu.LoadPercentage }
}

# Uptime
$uptimeSeconds = $null
if ($os -and $os.LastBootUpTime) {
  $uptimeSeconds = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalSeconds)
}

$result = [PSCustomObject]@{
  hostname        = if ($computer) { $computer.Name } elseif ($os) { $os.CSName } else { $env:COMPUTERNAME }
  os_caption      = if ($os) { $os.Caption } else { $null }
  os_build        = if ($os) { $os.BuildNumber } else { $null }
  os_version      = if ($os) { $os.Version } else { $null }
  architecture    = if ($os) { $os.OSArchitecture } else { $null }
  cpu_name        = if ($cpu) { $cpu.Name } else { $null }
  cpu_cores       = if ($cpu) { [int]$cpu.NumberOfLogicalProcessors } else { $null }
  cpu_percent     = $cpuPercent
  memory_total_gb = if ($os) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 2) } else { $null }
  memory_free_gb  = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { $null }
  disk_total_gb   = if ($diskTotalBytes -gt 0) { [math]::Round($diskTotalBytes / 1GB, 1) } else { $null }
  disk_free_gb    = if ($diskTotalBytes -gt 0) { [math]::Round($diskFreeBytes / 1GB, 1) } else { $null }
  disk_count      = $diskCount
  disks           = $diskList
  battery_percent = if ($battery) { [int]$battery.EstimatedChargeRemaining } else { $null }
  battery_status  = if ($battery) { [int]$battery.BatteryStatus } else { $null }
  uptime_seconds  = $uptimeSeconds
}

$result | ConvertTo-Json -Depth 4 -Compress
''';

  @override
  Future<SystemStatus> sample() async {
    if (!Platform.isWindows) {
      // Dev / CI fallback so the app still paints on macOS / Linux.
      return _fallbackSample();
    }

    // Run the heartbeat probe and the active-window probe in parallel
    // — they're separate PowerShell processes so they don't share the
    // (cold) C# compile cost of Add-Type, and a failure on either side
    // can't take the other down. Total wall-clock time is `max(both)`,
    // not `sum(both)`.
    final results = await Future.wait<dynamic>([
      _runHeartbeat(),
      _captureActiveWindow(),
    ]);

    final base = results[0] as SystemStatus;
    final window = results[1] as _ActiveWindow?;
    if (window == null) return base;
    return base.copyWith(
      activeWindowTitle: window.title,
      activeProcessName: window.processName,
    );
  }

  Future<SystemStatus> _runHeartbeat() async {
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

      if (result.exitCode != 0) {
        return _fallbackSample();
      }
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) {
        return _fallbackSample();
      }

      final decoded = jsonDecode(stdout);
      if (decoded is! Map<String, dynamic>) {
        return _fallbackSample();
      }

      return _fromPowerShellJson(decoded);
    } on TimeoutException {
      return _fallbackSample();
    } catch (_) {
      return _fallbackSample();
    }
  }

  /// Best-effort capture of the foreground window. Runs in its own
  /// PowerShell process with a generous (10s) timeout because the
  /// underlying `Add-Type` cmdlet has to invoke the C# compiler on a
  /// cold machine. Failures return `null` and the caller carries on
  /// with empty active-window fields rather than failing the heartbeat.
  Future<_ActiveWindow?> _captureActiveWindow() async {
    try {
      final result = await Process.run(
        powershellExecutable,
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          _activeWindowScript,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(_activeWindowTimeout);
      if (result.exitCode != 0) return null;
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) return null;
      final decoded = jsonDecode(stdout);
      if (decoded is! Map<String, dynamic>) return null;
      final title = _asNullableString(decoded['title']);
      final proc = _asNullableString(decoded['process']);
      if (title == null && proc == null) return null;
      return _ActiveWindow(title: title, processName: proc);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Generous timeout for the active-window probe — enough headroom
  /// for `Add-Type` cold-start C# compilation on a fresh machine.
  static const Duration _activeWindowTimeout = Duration(seconds: 10);

  // ------------------------------------------------------------------
  // Active-window script — isolated so a slow `Add-Type` compile can't
  // take the heartbeat probe down with it. Outputs a tiny JSON blob:
  //   { "title": "<window>", "process": "<exe>.exe" }
  // Either field may be null.
  // ------------------------------------------------------------------
  static const String _activeWindowScript = r'''
$ErrorActionPreference = 'SilentlyContinue'

$title = $null
$proc  = $null

try {
  Add-Type -Namespace 'NwForeground' -Name 'Native' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll", CharSet=System.Runtime.InteropServices.CharSet.Auto)]
public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder text, int count);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
'@ -ErrorAction Stop

  $hwnd = [NwForeground.Native]::GetForegroundWindow()
  if ($hwnd -ne [System.IntPtr]::Zero) {
    $sb = New-Object System.Text.StringBuilder 512
    [void][NwForeground.Native]::GetWindowText($hwnd, $sb, $sb.Capacity)
    $candidate = $sb.ToString().Trim()
    if ($candidate.Length -gt 0) { $title = $candidate }
    $procId = 0
    [void][NwForeground.Native]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    if ($procId -gt 0) {
      $p = $null
      try { $p = Get-Process -Id $procId -ErrorAction Stop } catch {}
      if ($p -and $p.ProcessName) { $proc = "$($p.ProcessName).exe" }
    }
  }
} catch {
  # Add-Type / user32 unavailable (locked desktop, session-0 service,
  # restricted .NET) — leave both fields null and emit an empty record.
}

[PSCustomObject]@{
  title   = $title
  process = $proc
} | ConvertTo-Json -Compress
''';

  @override
  Future<DeviceHardwareProfile> captureHardwareProfile() async {
    if (!Platform.isWindows) {
      return DeviceHardwareProfile.empty;
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
          _profileScript,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      if (result.exitCode != 0) return DeviceHardwareProfile.empty;
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) return DeviceHardwareProfile.empty;
      final decoded = jsonDecode(stdout);
      if (decoded is! Map<String, dynamic>) {
        return DeviceHardwareProfile.empty;
      }
      return _hardwareProfileFromJson(decoded);
    } on TimeoutException {
      return DeviceHardwareProfile.empty;
    } catch (_) {
      return DeviceHardwareProfile.empty;
    }
  }

  /// One-shot PowerShell script that captures the static hardware
  /// inventory. Deliberately separate from `_script` — this runs at
  /// most a handful of times per install (enrolment + opportunistic
  /// refresh), so there's no need to fold it into the hot heartbeat
  /// path.
  static const String _profileScript = r'''
$ErrorActionPreference = 'SilentlyContinue'

function TryGet {
  param([scriptblock]$Block)
  try { & $Block } catch { $null }
}

$os       = TryGet { Get-CimInstance -ClassName Win32_OperatingSystem }
$cpu      = TryGet { Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1 }
# Aggregate across every fixed volume so the `devices.disk_total_gb`
# inventory column reflects the whole workstation, not just C:\.
$disks    = TryGet { @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3") }
$diskTotalBytes = 0
if ($disks) {
  foreach ($d in $disks) {
    if ($d.Size) { $diskTotalBytes += [double]$d.Size }
  }
}
$computer = TryGet { Get-CimInstance -ClassName Win32_ComputerSystem }
$bios     = TryGet { Get-CimInstance -ClassName Win32_BIOS }

# Primary network adapter — pick the first IPEnabled adapter with a
# non-loopback IP so the dashboard shows the real LAN address.
$adapter = TryGet {
  Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" |
    Where-Object { $_.IPAddress -and $_.IPAddress[0] -and -not $_.IPAddress[0].StartsWith('169.254') } |
    Select-Object -First 1
}

$result = [PSCustomObject]@{
  manufacturer   = if ($computer) { $computer.Manufacturer } else { $null }
  model          = if ($computer) { $computer.Model } else { $null }
  serial_number  = if ($bios) { $bios.SerialNumber } else { $null }
  domain         = if ($computer) { $computer.Domain } else { $null }
  mac_address    = if ($adapter -and $adapter.MACAddress) { $adapter.MACAddress } else { $null }
  ip_address     = if ($adapter -and $adapter.IPAddress -and $adapter.IPAddress[0]) { $adapter.IPAddress[0] } else { $null }
  cpu_name       = if ($cpu) { $cpu.Name } else { $null }
  cpu_cores      = if ($cpu) { [int]$cpu.NumberOfLogicalProcessors } else { $null }
  architecture   = if ($os) { $os.OSArchitecture } else { $null }
  total_ram_gb   = if ($os) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 2) } else { $null }
  disk_total_gb  = if ($diskTotalBytes -gt 0) { [math]::Round($diskTotalBytes / 1GB, 1) } else { $null }
}

$result | ConvertTo-Json -Compress
''';

  DeviceHardwareProfile _hardwareProfileFromJson(Map<String, dynamic> j) {
    return DeviceHardwareProfile(
      manufacturer: _asString(j['manufacturer'], fallback: ''),
      model: _asString(j['model'], fallback: ''),
      serialNumber: _asString(j['serial_number'], fallback: ''),
      domain: _asString(j['domain'], fallback: ''),
      macAddress: _asString(j['mac_address'], fallback: ''),
      ipAddress: _asString(j['ip_address'], fallback: ''),
      cpuName: _asString(j['cpu_name'], fallback: '').trim(),
      cpuCores: _asIntOrNull(j['cpu_cores']) ?? 0,
      architecture:
          _asString(j['architecture'], fallback: '').replaceAll(' ', ''),
      totalRamGb: _asDouble(j['total_ram_gb']),
      diskTotalGb: _asDouble(j['disk_total_gb']),
    );
  }

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  SystemStatus _fromPowerShellJson(Map<String, dynamic> j) {
    final totalMem = _asDouble(j['memory_total_gb']);
    final freeMem = _asDouble(j['memory_free_gb']);
    final usedMem = totalMem > 0 ? (totalMem - freeMem).clamp(0, totalMem) : 0;

    final totalDisk = _asDouble(j['disk_total_gb']);
    final freeDisk = _asDouble(j['disk_free_gb']);
    final usedDisk =
        totalDisk > 0 ? (totalDisk - freeDisk).clamp(0, totalDisk) : 0;

    // `battery_status` decoded per Win32_Battery docs — 2 == charging /
    // connected to AC, anything else is either discharging or full on
    // AC. Treat 2 as charging for the UI.
    final batteryStatusCode = _asIntOrNull(j['battery_status']);
    final isCharging = batteryStatusCode == null ? null : batteryStatusCode == 2;

    return SystemStatus(
      deviceId: '',
      hostname: _asString(j['hostname'], fallback: 'this-pc'),
      os: _asString(j['os_caption'], fallback: 'Windows'),
      osBuild: _asString(j['os_build'], fallback: ''),
      architecture:
          _asString(j['architecture'], fallback: 'x64').replaceAll(' ', ''),
      cpuName: _asString(j['cpu_name'], fallback: 'Unknown CPU').trim(),
      cpuCores: _asIntOrNull(j['cpu_cores']) ?? 0,
      cpuUsagePercent: _asDouble(j['cpu_percent']).clamp(0, 100).toDouble(),
      totalRamGb: totalMem,
      usedRamGb: usedMem.toDouble(),
      diskTotalGb: totalDisk,
      diskUsedGb: usedDisk.toDouble(),
      uptimeSeconds: _asIntOrNull(j['uptime_seconds']) ?? 0,
      batteryPercent: _asIntOrNull(j['battery_percent']),
      isCharging: isCharging,
      timestamp: DateTime.now().toUtc(),
      // Active window is captured in a separate PowerShell process —
      // see [_captureActiveWindow]. We leave both fields null here and
      // copyWith over them once the parallel probe returns.
      activeWindowTitle: null,
      activeProcessName: null,
      disks: _disksFromJson(j['disks']),
    );
  }

  /// Parse the per-volume array. Tolerant — single-disk machines may
  /// see PowerShell flatten the one-element array into a Map, so we
  /// normalise both shapes.
  List<DiskVolume> _disksFromJson(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => DiskVolume.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    if (raw is Map) {
      return <DiskVolume>[DiskVolume.fromJson(Map<String, dynamic>.from(raw))];
    }
    return const <DiskVolume>[];
  }

  /// Like `_asString` but returns `null` for empty / missing values
  /// instead of substituting a fallback. Used for the active-window
  /// fields where "we don't know" is meaningfully different from
  /// "empty string".
  String? _asNullableString(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  SystemStatus _fallbackSample() => SystemStatus(
        deviceId: '',
        hostname: _safeHostname(),
        os: _safeOs(),
        osBuild: '',
        architecture: 'x64',
        cpuName: 'Unavailable',
        cpuCores: 0,
        cpuUsagePercent: 0,
        totalRamGb: 0,
        usedRamGb: 0,
        diskTotalGb: 0,
        diskUsedGb: 0,
        uptimeSeconds: 0,
        batteryPercent: null,
        isCharging: null,
        timestamp: DateTime.now().toUtc(),
      );

  String _safeHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'this-pc';
    }
  }

  String _safeOs() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'windows';
    }
  }

  // -- Tolerant converters -------------------------------------------

  double _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int? _asIntOrNull(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _asString(Object? v, {required String fallback}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }
}

/// Result of the parallel active-window capture. Both fields are
/// nullable because the foreground may be undefined on a locked
/// desktop / session-0 service.
class _ActiveWindow {
  const _ActiveWindow({this.title, this.processName});
  final String? title;
  final String? processName;
}
