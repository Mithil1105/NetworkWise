import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Immutable value object carrying every user-tunable preference.
///
/// Phase 11 will persist this through [ILocalStorage]. For now, defaults
/// come from [AppConstants] and live in memory only.
@immutable
class AppSettings {
  final ThemeMode themeMode;
  final int heartbeatSeconds;
  final double storageThresholdPercent;
  final double cpuWarningPercent;
  final double memoryWarningPercent;

  const AppSettings({
    required this.themeMode,
    required this.heartbeatSeconds,
    required this.storageThresholdPercent,
    required this.cpuWarningPercent,
    required this.memoryWarningPercent,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? heartbeatSeconds,
    double? storageThresholdPercent,
    double? cpuWarningPercent,
    double? memoryWarningPercent,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      heartbeatSeconds: heartbeatSeconds ?? this.heartbeatSeconds,
      storageThresholdPercent:
          storageThresholdPercent ?? this.storageThresholdPercent,
      cpuWarningPercent: cpuWarningPercent ?? this.cpuWarningPercent,
      memoryWarningPercent:
          memoryWarningPercent ?? this.memoryWarningPercent,
    );
  }

  factory AppSettings.defaults() {
    return const AppSettings(
      themeMode: ThemeMode.light,
      heartbeatSeconds: AppConstants.defaultHeartbeatSeconds,
      storageThresholdPercent: AppConstants.defaultStorageThresholdPercent,
      cpuWarningPercent: AppConstants.cpuWarningPercent,
      memoryWarningPercent: AppConstants.memoryWarningPercent,
    );
  }
}

/// Notifier holding the current [AppSettings]. Mutations are clamped
/// against the same bounds as the old singleton so UX is unchanged.
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.defaults();

  void setThemeMode(ThemeMode mode) {
    if (state.themeMode == mode) return;
    state = state.copyWith(themeMode: mode);
  }

  void setHeartbeatSeconds(int seconds) {
    final clamped = seconds.clamp(10, 600);
    if (clamped == state.heartbeatSeconds) return;
    state = state.copyWith(heartbeatSeconds: clamped);
  }

  void setStorageThresholdPercent(double value) {
    final clamped = value.clamp(50.0, 99.0);
    if (clamped == state.storageThresholdPercent) return;
    state = state.copyWith(storageThresholdPercent: clamped);
  }

  void setCpuWarningPercent(double value) {
    final clamped = value.clamp(50.0, 99.0);
    if (clamped == state.cpuWarningPercent) return;
    state = state.copyWith(cpuWarningPercent: clamped);
  }

  void setMemoryWarningPercent(double value) {
    final clamped = value.clamp(50.0, 99.0);
    if (clamped == state.memoryWarningPercent) return;
    state = state.copyWith(memoryWarningPercent: clamped);
  }

  void resetToDefaults() {
    state = AppSettings.defaults();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
