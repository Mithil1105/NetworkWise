import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/settings_provider.dart' show AppSettings;
import '../i_app_settings_repository.dart';

/// Supabase-backed implementation of [IAppSettingsRepository].
///
/// Reads the org-default row (the row where `device_id IS NULL`) from
/// the `app_settings` table. Writes upsert back to the same row.
///
/// In this first pass the repository is org-scoped only; per-device
/// overrides are a later concern and would simply key by `device_id`.
class SupabaseAppSettingsRepository implements IAppSettingsRepository {
  SupabaseAppSettingsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppSettings> load() async {
    final row = await _client
        .from('app_settings')
        .select()
        .filter('device_id', 'is', null)
        .maybeSingle();
    if (row == null) return AppSettings.defaults();
    return _mapRow(row);
  }

  @override
  Future<void> save(AppSettings settings) async {
    // Because `device_id IS NULL` is part of the UNIQUE constraint,
    // the easiest reliable upsert is: fetch the row once, then PATCH
    // or INSERT explicitly. PostgREST's `.upsert()` on a partial key
    // with NULL is awkward — this two-step is simpler and still
    // idempotent from the caller's perspective.
    final existing = await _client
        .from('app_settings')
        .select('id')
        .filter('device_id', 'is', null)
        .maybeSingle();

    final payload = _toRow(settings);
    if (existing == null) {
      await _client.from('app_settings').insert(payload);
    } else {
      await _client
          .from('app_settings')
          .update(payload)
          .eq('id', existing['id'] as String);
    }
  }

  @override
  Stream<void> watch() {
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('public:app_settings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_settings',
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
  // Mapping
  // ------------------------------------------------------------------

  AppSettings _mapRow(Map<String, dynamic> row) {
    ThemeMode theme(Object? v) {
      switch (v) {
        case 'dark':
          return ThemeMode.dark;
        case 'system':
          return ThemeMode.system;
        default:
          return ThemeMode.light;
      }
    }

    return AppSettings(
      themeMode: theme(row['theme_mode']),
      heartbeatSeconds: (row['heartbeat_seconds'] as num?)?.toInt() ?? 30,
      storageThresholdPercent:
          (row['storage_threshold_percent'] as num?)?.toDouble() ?? 85.0,
      cpuWarningPercent:
          (row['cpu_warning_percent'] as num?)?.toDouble() ?? 80.0,
      memoryWarningPercent:
          (row['memory_warning_percent'] as num?)?.toDouble() ?? 85.0,
    );
  }

  Map<String, dynamic> _toRow(AppSettings s) {
    String theme(ThemeMode v) {
      switch (v) {
        case ThemeMode.dark:
          return 'dark';
        case ThemeMode.system:
          return 'system';
        case ThemeMode.light:
          return 'light';
      }
    }

    return <String, dynamic>{
      'theme_mode': theme(s.themeMode),
      'heartbeat_seconds': s.heartbeatSeconds,
      'storage_threshold_percent': s.storageThresholdPercent,
      'cpu_warning_percent': s.cpuWarningPercent,
      'memory_warning_percent': s.memoryWarningPercent,
    };
  }
}
