import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Kinds of operations the queue is willing to persist + replay.
/// Keep this enum small — unknown values are dropped on load so the
/// app never ships a corrupt pending queue into a future release.
enum SyncOpKind {
  heartbeat,
  snapshot,
  // Phase 18 — append a full SecurityStatus + multi-AV inventory row
  // via the `report-snapshot` Edge Function. Distinct from the legacy
  // `snapshot` kind so the two cadences (fast telemetry vs. slower
  // security posture) can evolve independently.
  securitySnapshot,
  reportAlert,
  acknowledgeAlert,
  resolveAlert,
}

SyncOpKind? _parseKind(String? raw) {
  for (final k in SyncOpKind.values) {
    if (k.name == raw) return k;
  }
  return null;
}

/// A single pending write. `payload` carries whatever the write path
/// needs to reproduce the call — the queue itself is payload-agnostic.
class SyncOp {
  SyncOp({
    required this.id,
    required this.kind,
    required this.payload,
    required this.enqueuedAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final SyncOpKind kind;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'payload': payload,
        'enqueued_at': enqueuedAt.toIso8601String(),
        'attempts': attempts,
        if (lastError != null) 'last_error': lastError,
      };

  static SyncOp? fromJson(Map<String, dynamic> json) {
    final kind = _parseKind(json['kind'] as String?);
    if (kind == null) return null;
    return SyncOp(
      id: json['id'] as String,
      kind: kind,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      enqueuedAt: DateTime.parse(json['enqueued_at'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
    );
  }
}

/// Callback signature used by [SyncQueue.drain] to actually execute a
/// pending operation. Implementations must:
///   * return `true` on success (the op is removed),
///   * return `false` on a retriable failure (stays in the queue),
///   * throw on a non-retriable failure (op is dropped + logged).
typedef SyncExecutor = Future<bool> Function(SyncOp op);

/// Thin FIFO queue of outgoing writes.
///
/// Persistence is intentionally cheap — the whole queue is serialised
/// as a single JSON array under one SharedPreferences key. This is
/// fine for the expected volume (few hundred items in the worst
/// offline-a-whole-day case); if the queue ever pressures prefs we
/// switch to Hive without changing callers.
class SyncQueue {
  SyncQueue({
    SharedPreferences? prefs,
    Uuid? uuid,
    Duration drainInterval = const Duration(seconds: 30),
  })  : _prefs = prefs,
        _uuid = uuid ?? const Uuid(),
        _drainInterval = drainInterval;

  static const _storageKey = 'sync.queue.v1';

  SharedPreferences? _prefs;
  final Uuid _uuid;
  Duration _drainInterval;
  Timer? _timer;
  SyncExecutor? _executor;

  /// In-memory mirror of the persisted queue — exposed via [pending]
  /// so the UI can surface a "N items queued" badge without hitting
  /// disk on every rebuild.
  final List<SyncOp> _ops = <SyncOp>[];

  List<SyncOp> get pending => List<SyncOp>.unmodifiable(_ops);

  /// Loads the persisted queue into memory. Must be awaited before
  /// [enqueue] or [start].
  Future<void> load() async {
    final prefs = await _p();
    final raw = prefs.getString(_storageKey);
    _ops.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>).cast<dynamic>();
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final op = SyncOp.fromJson(entry);
        if (op != null) _ops.add(op);
      }
    } catch (_) {
      // Corrupt queue — wipe and start fresh rather than wedge boot.
      await prefs.remove(_storageKey);
    }
  }

  /// Begin draining on a periodic timer. [executor] is invoked once per
  /// pending op per tick; ordering is strictly FIFO — the queue stops
  /// on the first failure and retries on the next tick.
  void start(SyncExecutor executor) {
    _executor = executor;
    _timer?.cancel();
    _timer = Timer.periodic(_drainInterval, (_) => unawaited(drain()));
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _executor = null;
  }

  /// Adjust the drain cadence — handy when heartbeat cadence changes.
  void setDrainInterval(Duration interval) {
    final clampedSeconds = interval.inSeconds.clamp(5, 3600);
    final next = Duration(seconds: clampedSeconds);
    if (next == _drainInterval) return;
    _drainInterval = next;
    if (_timer != null && _executor != null) {
      start(_executor!);
    }
  }

  /// Persist + remember a new operation. Returns the assigned id.
  Future<String> enqueue(SyncOpKind kind, Map<String, dynamic> payload) async {
    final op = SyncOp(
      id: _uuid.v4(),
      kind: kind,
      payload: payload,
      enqueuedAt: DateTime.now().toUtc(),
    );
    _ops.add(op);
    await _persist();
    return op.id;
  }

  /// Walk the queue and hand each op to [executor] in order. Stops on
  /// the first non-success.
  Future<void> drain() async {
    if (_executor == null) return;
    while (_ops.isNotEmpty) {
      final op = _ops.first;
      try {
        final ok = await _executor!(op);
        if (!ok) {
          op.attempts += 1;
          op.lastError = 'retry';
          await _persist();
          return; // stop — retry next tick.
        }
        _ops.removeAt(0);
        await _persist();
      } catch (err) {
        // Non-retriable — drop the op so the queue doesn't wedge.
        op.attempts += 1;
        op.lastError = err.toString();
        _ops.removeAt(0);
        await _persist();
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await _p();
    final json = jsonEncode(_ops.map((o) => o.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();
}
