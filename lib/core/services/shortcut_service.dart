import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 25 — creates / removes Windows .lnk shortcuts in the user's
/// Desktop and Start Menu folders. Driven from the Settings panel so
/// operators can put NetworkWise in front of staff without futzing
/// around in File Explorer themselves.
///
/// We deliberately do NOT attempt to pin to the taskbar. Microsoft
/// removed programmatic taskbar pinning in Windows 10 — the only
/// supported paths are MSIX install metadata or a user-driven right
/// click. The Settings panel surfaces a one-line instruction for the
/// latter; everything else is handled here.
class ShortcutService {
  ShortcutService();

  /// Friendly file name used for both the desktop and Start Menu
  /// shortcuts. Picking a single name keeps cleanup logic simple.
  static const String _shortcutName = 'NetworkWise.lnk';

  /// Plain (visible) launch — for end-users who want to click the icon
  /// and see the dashboard.
  Future<void> createDesktopShortcut({bool background = false}) async {
    _requireWindows();
    final target = await _desktopPath();
    await _writeLnk(
      lnkPath: '$target\\$_shortcutName',
      targetExe: Platform.resolvedExecutable,
      arguments: background ? '--background' : '',
      description: background
          ? 'NetworkWise — endpoint agent (runs hidden)'
          : 'NetworkWise — IT management dashboard',
    );
  }

  Future<void> removeDesktopShortcut() async {
    _requireWindows();
    final target = await _desktopPath();
    await _deleteIfExists('$target\\$_shortcutName');
  }

  Future<void> createStartMenuShortcut({bool background = false}) async {
    _requireWindows();
    final dir = await _startMenuPath();
    // The Start Menu folder always exists, but defensively create our
    // own subfolder anyway so the shortcut doesn't end up next to
    // every other randomly-installed app.
    final folder = Directory('$dir\\NetworkWise');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    await _writeLnk(
      lnkPath: '${folder.path}\\$_shortcutName',
      targetExe: Platform.resolvedExecutable,
      arguments: background ? '--background' : '',
      description: background
          ? 'NetworkWise — endpoint agent (runs hidden)'
          : 'NetworkWise — IT management dashboard',
    );
  }

  Future<void> removeStartMenuShortcut() async {
    _requireWindows();
    final dir = await _startMenuPath();
    final folder = Directory('$dir\\NetworkWise');
    final lnk = File('${folder.path}\\$_shortcutName');
    if (await lnk.exists()) {
      await lnk.delete();
    }
    if (await folder.exists()) {
      // Only remove the folder if it's now empty — don't blow away
      // anything else the user might have stashed in there.
      final entries = await folder.list().toList();
      if (entries.isEmpty) {
        await folder.delete();
      }
    }
  }

  /// Quick read of which shortcuts currently exist. Used by the
  /// Settings panel to render the right verb on each button (Create vs
  /// Recreate vs Remove).
  Future<ShortcutState> currentState() async {
    if (!Platform.isWindows) {
      return const ShortcutState(
        supported: false,
        desktop: false,
        startMenu: false,
      );
    }
    try {
      final desktop = await _desktopPath();
      final startMenu = await _startMenuPath();
      final desktopLnk = File('$desktop\\$_shortcutName');
      final startMenuLnk = File('$startMenu\\NetworkWise\\$_shortcutName');
      return ShortcutState(
        supported: true,
        desktop: await desktopLnk.exists(),
        startMenu: await startMenuLnk.exists(),
      );
    } catch (_) {
      return const ShortcutState(
        supported: true,
        desktop: false,
        startMenu: false,
      );
    }
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  void _requireWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Shortcuts are only supported on Windows.');
    }
  }

  /// Resolve the user's Desktop folder. We could read it from
  /// `SHGetKnownFolderPath` via FFI, but the env var is reliable on
  /// every modern Windows and avoids the platform-channel detour.
  Future<String> _desktopPath() async {
    final fromEnv = Platform.environment['USERPROFILE'];
    if (fromEnv == null || fromEnv.isEmpty) {
      throw StateError('USERPROFILE environment variable is not set.');
    }
    return '$fromEnv\\Desktop';
  }

  Future<String> _startMenuPath() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw StateError('APPDATA environment variable is not set.');
    }
    return '$appData\\Microsoft\\Windows\\Start Menu\\Programs';
  }

  /// Drives PowerShell's COM automation to write a real .lnk file.
  /// Using WScript.Shell is the simplest reliable path — it handles
  /// long paths, Unicode, and shell-folder resolution exactly the way
  /// File Explorer does. Errors bubble up so the caller can surface
  /// them on the Settings card.
  Future<void> _writeLnk({
    required String lnkPath,
    required String targetExe,
    required String arguments,
    required String description,
  }) async {
    // Escape backslashes + double-quotes so the script literal stays
    // valid inside a PowerShell single-quoted block.
    String esc(String s) => s.replaceAll("'", "''");
    final workingDir = File(targetExe).parent.path;

    final script = '''
\$ws = New-Object -ComObject WScript.Shell
\$lnk = \$ws.CreateShortcut('${esc(lnkPath)}')
\$lnk.TargetPath = '${esc(targetExe)}'
\$lnk.Arguments  = '${esc(arguments)}'
\$lnk.WorkingDirectory = '${esc(workingDir)}'
\$lnk.IconLocation = '${esc(targetExe)},0'
\$lnk.Description = '${esc(description)}'
\$lnk.Save()
''';

    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
      ],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Could not write shortcut — PowerShell exited '
        '${result.exitCode}: ${result.stderr}',
      );
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}

class ShortcutState {
  const ShortcutState({
    required this.supported,
    required this.desktop,
    required this.startMenu,
  });

  /// False on non-Windows hosts; UI hides the section entirely.
  final bool supported;

  /// True when ~\Desktop\NetworkWise.lnk exists.
  final bool desktop;

  /// True when the Start Menu shortcut exists.
  final bool startMenu;
}

final shortcutServiceProvider = Provider<ShortcutService>((ref) {
  return ShortcutService();
});

final shortcutStateProvider = FutureProvider<ShortcutState>((ref) async {
  final svc = ref.watch(shortcutServiceProvider);
  return svc.currentState();
});
