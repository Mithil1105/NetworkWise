import 'package:shared_preferences/shared_preferences.dart';

/// Persists the enrollment code the operator typed on first run.
///
/// The code itself is not secret — anyone inside the org can read it —
/// so we keep it in SharedPreferences rather than DPAPI. Once the
/// endpoint has exchanged it for a `registration_secret`, the code can
/// be forgotten (but we keep it around so "re-register" flows don't
/// need to prompt the user again).
class EnrollmentService {
  EnrollmentService({SharedPreferences? prefs}) : _prefs = prefs;

  static const _kCode = 'enrollment.code';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Returns the last code the user stored, or `null` if the endpoint
  /// has never been enrolled.
  Future<String?> read() async {
    final prefs = await _p();
    final raw = prefs.getString(_kCode);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  /// Normalises and stores the code — upper-cased, trimmed, dashes kept.
  Future<void> write(String code) async {
    final prefs = await _p();
    await prefs.setString(_kCode, code.trim().toUpperCase());
  }

  /// Used by "factory reset" / "un-enroll" flows.
  Future<void> clear() async {
    final prefs = await _p();
    await prefs.remove(_kCode);
  }
}
