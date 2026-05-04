/// App-wide numeric & key constants.
///
/// Keep this file free of UI / Flutter imports so it can be used from
/// services, models, and platform channels without coupling.
class AppConstants {
  const AppConstants._();

  // --- App metadata ---
  static const String appName = 'NetworkWise';
  static const String appTagline = 'IT Management Dashboard';
  static const String appVersion = '1.0.0';

  // --- Layout ---
  static const double sidebarWidth = 248;
  static const double sidebarCollapsedWidth = 72;
  static const double topBarHeight = 64;
  static const double defaultPadding = 16;
  static const double cardRadius = 12;

  // --- Timing ---
  static const Duration defaultAnimation = Duration(milliseconds: 220);
  static const Duration heartbeatDefault = Duration(seconds: 30);
  static const Duration refreshDebounce = Duration(milliseconds: 400);

  // --- Thresholds (defaults; overridable via Settings) ---
  static const int defaultHeartbeatSeconds = 30;
  static const double defaultStorageThresholdPercent = 85.0;
  static const double cpuWarningPercent = 80.0;
  static const double memoryWarningPercent = 85.0;

  // --- Storage keys ---
  static const String kThemeMode = 'pref.themeMode';
  static const String kHeartbeatInterval = 'pref.heartbeatInterval';
  static const String kStorageThreshold = 'pref.storageThreshold';
}
