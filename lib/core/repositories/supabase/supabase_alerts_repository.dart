import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/alert.dart';
import '../i_alerts_repository.dart';

/// Supabase-backed implementation of [IAlertsRepository].
///
/// Reads → PostgREST.
/// Writes → Edge Functions:
///   * Create a new alert → `report-alert`
///   * State transitions  → `update-alert-status`
class SupabaseAlertsRepository implements IAlertsRepository {
  SupabaseAlertsRepository(this._client);

  final SupabaseClient _client;

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  @override
  Future<List<Alert>> listAlerts() async {
    final rows = await _client
        .from('alerts')
        .select()
        .order('occurred_at', ascending: false)
        .limit(500);
    return rows
        .map((r) => _mapRow(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Stream<void> watchAlerts() {
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  // ------------------------------------------------------------------
  // Writes
  // ------------------------------------------------------------------

  @override
  Future<String> reportAlert({
    required String deviceId,
    required String registrationSecret,
    required String title,
    String? message,
    required AlertSeverity severity,
    required AlertCategory category,
    String? source,
    DateTime? occurredAt,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'registration_secret': registrationSecret,
      'title': title,
      if (message != null) 'message': message,
      'severity': severity.name,
      'category': category.name,
      if (source != null) 'source': source,
      if (occurredAt != null) 'occurred_at': occurredAt.toIso8601String(),
    };
    final response =
        await _client.functions.invoke('report-alert', body: body);
    _throwIfFailed(response, 'report-alert');
    final data = response.data;
    if (data is! Map || data['alert_id'] is! String) {
      throw StateError('report-alert returned unexpected payload: $data');
    }
    return data['alert_id'] as String;
  }

  @override
  Future<void> acknowledgeAlert({
    required String deviceId,
    required String registrationSecret,
    required String alertId,
    String? actor,
  }) async {
    await _transition(
      deviceId: deviceId,
      registrationSecret: registrationSecret,
      alertId: alertId,
      action: 'acknowledge',
      actor: actor,
    );
  }

  @override
  Future<void> resolveAlert({
    required String deviceId,
    required String registrationSecret,
    required String alertId,
    String? actor,
  }) async {
    await _transition(
      deviceId: deviceId,
      registrationSecret: registrationSecret,
      alertId: alertId,
      action: 'resolve',
      actor: actor,
    );
  }

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------

  Future<void> _transition({
    required String deviceId,
    required String registrationSecret,
    required String alertId,
    required String action,
    String? actor,
  }) async {
    final body = <String, dynamic>{
      'device_id': deviceId,
      'registration_secret': registrationSecret,
      'alert_id': alertId,
      'action': action,
      if (actor != null) 'actor': actor,
    };
    final response = await _client.functions.invoke(
      'update-alert-status',
      body: body,
    );
    _throwIfFailed(response, 'update-alert-status');
  }

  Alert _mapRow(Map<String, dynamic> row) {
    return Alert(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      message: (row['message'] as String?) ?? '',
      severity: _parseEnum(
        row['severity'],
        AlertSeverity.values,
        AlertSeverity.info,
      ),
      status: _parseEnum(
        row['status'],
        AlertStatus.values,
        AlertStatus.open,
      ),
      category: _parseEnum(
        row['category'],
        AlertCategory.values,
        AlertCategory.other,
      ),
      timestamp: DateTime.parse(row['occurred_at'] as String),
      deviceId: row['device_id'] as String?,
      source: row['source'] as String?,
    );
  }

  static T _parseEnum<T extends Enum>(
    Object? raw,
    List<T> values,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  void _throwIfFailed(FunctionResponse r, String name) {
    if (r.status != null && r.status! >= 400) {
      throw StateError('$name failed (${r.status}): ${r.data}');
    }
  }
}
