import '../providers/settings_provider.dart' show AppSettings;

/// Contract for the organization-scoped **app_settings** row.
///
/// Holds the org-level defaults used to seed a new endpoint:
///   * `heartbeat_seconds`
///   * `storage_threshold_percent`
///   * `cpu_warning_percent`
///   * `memory_warning_percent`
///   * `theme_mode`
///
/// Individual endpoints can still override any of these locally via the
/// Settings screen. The repository only mediates the cloud row.
abstract class IAppSettingsRepository {
  /// Load the app_settings row for the current organization. Returns
  /// the Supabase defaults when the row is missing so the caller never
  /// has to null-check.
  Future<AppSettings> load();

  /// Push the current [AppSettings] back to the cloud.
  ///
  /// Only the Owner role of the org should call this in practice; the
  /// UI wire-up will be added in a later phase.
  Future<void> save(AppSettings settings);

  /// Fires whenever the cloud row changes — consumers should re-read
  /// via [load].
  Stream<void> watch();
}
