import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_usage.dart';

/// Phase 22 — derives screen-time + per-app minutes from `heartbeat_logs`.
///
/// We deliberately do NOT keep a separate "activity" table. Every
/// heartbeat is already a 60-second sample of what the user is doing,
/// so any GROUP BY over `active_process_name` reproduces app-usage
/// minutes without a second write path. This keeps the data model
/// honest — there's only one source of truth — and lets us tweak the
/// aggregation without redeploying the endpoint.
class SupabaseActivityRepository {
  SupabaseActivityRepository(this._client);

  final SupabaseClient _client;

  /// Default heartbeat cadence assumed when converting "row count" into
  /// "minutes". Matches `AppConstants.defaultHeartbeatSeconds` — kept
  /// in sync via the `heartbeatSeconds` argument so callers can pass
  /// the user's configured cadence when known.
  static const int defaultHeartbeatSeconds = 60;

  /// Fetch + aggregate activity for [deviceId] over the [from..to)
  /// window. Returns an [AppUsageSummary] sorted by per-app seconds
  /// descending.
  ///
  /// Aggregation runs client-side because PostgREST doesn't expose
  /// arbitrary SQL — for the size of data we deal with (a few thousand
  /// rows over 7 days) the latency hit is negligible, and it lets us
  /// keep the schema unchanged. When the table outgrows that, this
  /// method should move behind a Postgres view or RPC.
  Future<AppUsageSummary> summarise({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    int heartbeatSeconds = defaultHeartbeatSeconds,
  }) async {
    final fromUtc = from.toUtc();
    final toUtc = to.toUtc();

    // Pull the columns we actually need. Cap to a sensible row limit
    // so a misconfigured probe (10s cadence × 30 days × 1 device =
    // 260k rows) can't blow up the client.
    final rows = await _client
        .from('heartbeat_logs')
        .select('active_process_name, reported_at')
        .eq('device_id', deviceId)
        .gte('reported_at', fromUtc.toIso8601String())
        .lt('reported_at', toUtc.toIso8601String())
        .order('reported_at', ascending: true)
        .limit(50000);

    int totalHeartbeats = 0;
    int idleHeartbeats = 0;

    // Per-process aggregation: process -> (heartbeatCount, lastSeen)
    final buckets = <String, _BucketAccumulator>{};

    for (final raw in rows) {
      final r = raw as Map<String, dynamic>;
      totalHeartbeats++;
      final reportedRaw = r['reported_at'];
      final reportedAt = reportedRaw is String
          ? DateTime.tryParse(reportedRaw)?.toUtc()
          : null;
      final proc = (r['active_process_name'] as String?)?.trim();
      if (proc == null || proc.isEmpty) {
        idleHeartbeats++;
        continue;
      }
      final acc = buckets.putIfAbsent(proc, _BucketAccumulator.new);
      acc.heartbeatCount++;
      if (reportedAt != null &&
          (acc.lastSeenAt == null || reportedAt.isAfter(acc.lastSeenAt!))) {
        acc.lastSeenAt = reportedAt;
      }
    }

    final activeHeartbeats = totalHeartbeats - idleHeartbeats;
    final totalActiveSeconds = activeHeartbeats * heartbeatSeconds;

    final byApp = buckets.entries
        .map(
          (e) => AppUsageBucket(
            processName: e.key,
            seconds: e.value.heartbeatCount * heartbeatSeconds,
            heartbeatCount: e.value.heartbeatCount,
            lastSeenAt: e.value.lastSeenAt ?? fromUtc,
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => b.seconds.compareTo(a.seconds));

    return AppUsageSummary(
      deviceId: deviceId,
      windowStart: fromUtc,
      windowEnd: toUtc,
      heartbeatSeconds: heartbeatSeconds,
      totalActiveSeconds: totalActiveSeconds,
      totalHeartbeats: totalHeartbeats,
      idleHeartbeats: idleHeartbeats,
      byApp: byApp,
    );
  }
}

class _BucketAccumulator {
  int heartbeatCount = 0;
  DateTime? lastSeenAt;
}
