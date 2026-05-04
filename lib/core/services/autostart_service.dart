import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 24 — manages the HKCU `Run` entry that re-launches the
/// endpoint agent on every login in `--background` mode.
///
/// We deliberately use the per-user registry hive (HKCU) rather than
/// HKLM so the toggle works without UAC elevation — a CA firm rolling
/// the agent onto staff workstations doesn't want to elevate every
/// install. The trade-off is that the agent only autostarts for the
/// currently signed-in user; if multiple users share a workstation,
/// each one would need to opt in independently. For the firm's actual
/// fleet (one user per machine) that's fine.
///
/// The reg.exe shell-out is the simplest reliable way to manipulate
/// the registry from Dart on Windows without pulling in another plugin.
/// All three operations (query / add / delete) finish in <50ms on a
/// warm machine.
class AutostartService {
  AutostartService();

  static const String _registryPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _registryValue = 'NetworkWiseEndpoint';

  /// True when the HKCU Run entry exists and points to the current
  /// executable. Returning `false` for missing entry OR for an entry
  /// pointing somewhere else (e.g. a stale install path) so the
  /// Settings UI can offer to refresh it.
  Future<AutostartState> currentState() async {
    if (!Platform.isWindows) {
      return const AutostartState(installed: false, supported: false);
    }
    try {
      final result = await Process.run(
        'reg',
        ['query', _registryPath, '/v', _registryValue],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        return const AutostartState(installed: false, supported: true);
      }
      final stdout = result.stdout as String;
      final command = _extractCommand(stdout);
      final myExe = Platform.resolvedExecutable;
      final pointsToMe =
          command != null && command.toLowerCase().contains(myExe.toLowerCase());
      return AutostartState(
        installed: command != null,
        supported: true,
        registeredCommand: command,
        pointsToCurrentInstall: pointsToMe,
      );
    } catch (_) {
      return const AutostartState(installed: false, supported: true);
    }
  }

  /// Register the current executable to launch in `--background` mode
  /// at every Windows login. Idempotent — re-running this with `/f`
  /// just overwrites whatever was there.
  Future<void> install() async {
    _requireWindows();
    final exePath = Platform.resolvedExecutable;
    // The /d argument is the value to write. We deliberately wrap the
    // exe path in escaped quotes so paths with spaces (almost every
    // production install on Windows) round-trip correctly through reg.exe.
    final command = '"$exePath" --background';
    final result = await Process.run(
      'reg',
      [
        'add',
        _registryPath,
        '/v',
        _registryValue,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ],
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Failed to register autostart — reg.exe exited '
        '${result.exitCode}: ${result.stderr}',
      );
    }
  }

  /// Remove the autostart entry. Treats "key not found" as success so
  /// the operator can call this defensively without checking state first.
  Future<void> uninstall() async {
    _requireWindows();
    final result = await Process.run(
      'reg',
      ['delete', _registryPath, '/v', _registryValue, '/f'],
      runInShell: false,
    );
    if (result.exitCode != 0 && result.exitCode != 1) {
      // exit code 1 == key not found (already gone). Treat as a no-op.
      throw StateError(
        'Failed to remove autostart — reg.exe exited '
        '${result.exitCode}: ${result.stderr}',
      );
    }
  }

  void _requireWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Autostart toggle is only supported on Windows.',
      );
    }
  }

  /// Pulls the value column out of `reg query` output. Sample line:
  ///   "    NetworkWiseEndpoint    REG_SZ    \"C:\\Program Files\\…\\app.exe\" --background"
  static String? _extractCommand(String output) {
    final lines = output.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (!line.contains(_registryValue)) continue;
      // Split on whitespace; everything after REG_SZ is the value.
      final marker = RegExp(r'\bREG_(SZ|EXPAND_SZ)\b');
      final match = marker.firstMatch(line);
      if (match == null) continue;
      final after = line.substring(match.end).trim();
      return after.isEmpty ? null : after;
    }
    return null;
  }
}

/// Snapshot of where the autostart toggle currently stands.
class AutostartState {
  const AutostartState({
    required this.installed,
    required this.supported,
    this.registeredCommand,
    this.pointsToCurrentInstall = false,
  });

  /// True when an autostart entry exists.
  final bool installed;

  /// False on non-Windows hosts (dev / CI). The Settings panel should
  /// hide the toggle entirely in that case.
  final bool supported;

  /// The full command currently registered in HKCU — useful for
  /// surfacing when the entry points to a stale install path.
  final String? registeredCommand;

  /// True when the registered command resolves to the running exe.
  final bool pointsToCurrentInstall;
}

final autostartServiceProvider = Provider<AutostartService>((ref) {
  return AutostartService();
});

/// Live-refreshable view of the autostart state. The Settings UI can
/// invalidate this provider after a successful install/uninstall to
/// refresh the toggle without a full page rebuild.
final autostartStateProvider = FutureProvider<AutostartState>((ref) async {
  final svc = ref.watch(autostartServiceProvider);
  return svc.currentState();
});
