import 'package:flutter/foundation.dart';

/// Aggregated screen-time summary for a single device over a date
/// range — derived by counting `heartbeat_logs` rows GROUP BY
/// `active_process_name` and multiplying by the heartbeat cadence.
@immutable
class AppUsageSummary {
  const AppUsageSummary({
    required this.deviceId,
    required this.windowStart,
    required this.windowEnd,
    required this.heartbeatSeconds,
    required this.totalActiveSeconds,
    required this.totalHeartbeats,
    required this.idleHeartbeats,
    required this.byApp,
  });

  final String deviceId;
  final DateTime windowStart;
  final DateTime windowEnd;

  /// Heartbeat cadence assumed when converting "row count" into "minutes".
  /// We pass it in instead of hard-coding 60 so the math stays correct
  /// if Settings ▸ Heartbeat seconds is ever changed.
  final int heartbeatSeconds;

  /// Total seconds the user actively had a foreground window during
  /// the window. Locked-screen heartbeats are excluded.
  final int totalActiveSeconds;

  /// Total number of heartbeat rows seen — useful for sanity checks
  /// and for computing "% of time at desk".
  final int totalHeartbeats;

  /// Heartbeats where the foreground was undefined (locked desktop or
  /// session-0 service). `totalHeartbeats - idleHeartbeats` gives the
  /// number of "active" ticks.
  final int idleHeartbeats;

  /// Per-application breakdown sorted by [seconds] descending.
  final List<AppUsageBucket> byApp;

  Duration get totalActive => Duration(seconds: totalActiveSeconds);

  /// Wall-clock seconds covered by the window (the user may have been
  /// away from the keyboard for part of it).
  int get windowSeconds => windowEnd.difference(windowStart).inSeconds;

  /// Active proportion — how much of the window had a foreground app.
  double get activePercent {
    final total = totalHeartbeats * heartbeatSeconds;
    if (total <= 0) return 0;
    return (totalActiveSeconds / total) * 100.0;
  }
}

/// One row in the per-app breakdown.
@immutable
class AppUsageBucket {
  const AppUsageBucket({
    required this.processName,
    required this.seconds,
    required this.heartbeatCount,
    required this.lastSeenAt,
  });

  /// e.g. `EXCEL.EXE`, `chrome.exe`. May be empty when the probe
  /// couldn't resolve the process — those rows still count toward
  /// active time, just under the literal label "Unknown".
  final String processName;

  final int seconds;
  final int heartbeatCount;
  final DateTime lastSeenAt;

  Duration get duration => Duration(seconds: seconds);

  String get displayName {
    final p = processName.trim();
    if (p.isEmpty) return 'Unknown';
    // Most users recognise the process name without the .exe suffix.
    if (p.toLowerCase().endsWith('.exe')) {
      return p.substring(0, p.length - 4);
    }
    return p;
  }
}
