import 'package:supabase_flutter/supabase_flutter.dart';

import 'organization_summary.dart';

/// Thin service over the admin-only reads + RPCs needed by the Settings
/// screen. Keeps the Supabase call sites out of the UI layer and gives
/// us one place to evolve (e.g. add caching, retry, etc.) later.
///
/// All methods assume the caller is signed-in as an admin — RLS on
/// `organizations` (policy `organizations_admin_read`) and the
/// `rotate-enrollment-code` Edge Function both enforce membership in
/// `admin_members` server-side.
class OrganizationService {
  OrganizationService(this._client);

  final SupabaseClient _client;

  /// Reads the caller's organisation row. The row is scoped by RLS, so
  /// we simply select the one row the signed-in admin is allowed to see.
  ///
  /// Returns `null` if no row comes back (shouldn't happen in practice —
  /// the sign-in gate already confirmed admin membership).
  Future<OrganizationSummary?> fetchCurrent() async {
    final row = await _client
        .from('organizations')
        .select(
          'id, slug, name, enrollment_code, enrollment_code_rotated_at, created_at',
        )
        .maybeSingle();
    if (row == null) return null;
    return OrganizationSummary.fromRow(Map<String, dynamic>.from(row));
  }

  /// Invokes the `rotate-enrollment-code` Edge Function. Returns the
  /// freshly-minted code and the timestamp stamped on the organisation
  /// row.
  Future<RotatedEnrollmentCode> rotateEnrollmentCode() async {
    final response = await _client.functions.invoke('rotate-enrollment-code');
    final status = response.status;
    if (status != null && status >= 400 && status < 600) {
      throw StateError(
        'rotate-enrollment-code failed ($status): ${response.data}',
      );
    }
    final data = response.data;
    if (data is! Map ||
        data['enrollment_code'] is! String ||
        data['rotated_at'] is! String) {
      throw StateError(
        'rotate-enrollment-code returned an unexpected payload: $data',
      );
    }
    return RotatedEnrollmentCode(
      code: data['enrollment_code'] as String,
      rotatedAt: DateTime.parse(data['rotated_at'] as String),
    );
  }
}

/// Result of a successful enrollment-code rotation.
class RotatedEnrollmentCode {
  const RotatedEnrollmentCode({required this.code, required this.rotatedAt});

  final String code;
  final DateTime rotatedAt;
}
