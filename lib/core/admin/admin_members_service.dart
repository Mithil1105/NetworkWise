import 'package:supabase_flutter/supabase_flutter.dart';

/// Row from `admin_members` — minimal shape for the Settings list.
class AdminMemberRow {
  const AdminMemberRow({
    required this.userId,
    required this.organizationId,
    required this.role,
    required this.fullName,
    required this.createdAt,
  });

  final String userId;
  final String organizationId;
  final String role; // 'admin' | 'owner'
  final String? fullName;
  final DateTime createdAt;

  factory AdminMemberRow.fromRow(Map<String, dynamic> row) {
    return AdminMemberRow(
      userId: row['user_id'] as String,
      organizationId: row['organization_id'] as String,
      role: (row['role'] as String?) ?? 'admin',
      fullName: row['full_name'] as String?,
      createdAt: row['created_at'] is String
          ? DateTime.tryParse(row['created_at'] as String) ??
              DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}

/// Admin-only service for inviting new admins and (eventually) revoking
/// access. Server-side policies make this call a no-op for non-admins.
class AdminMembersService {
  AdminMembersService(this._client);

  final SupabaseClient _client;

  /// Lists the caller's own row (RLS scopes admin_members to `user_id =
  /// auth.uid()`). We return a list because a future migration may
  /// surface every admin in the org to owners.
  Future<List<AdminMemberRow>> listMyMembership() async {
    final rows = await _client
        .from('admin_members')
        .select('user_id, organization_id, role, full_name, created_at');
    return (rows as List)
        .map((r) => AdminMemberRow.fromRow(Map<String, dynamic>.from(r)))
        .toList(growable: false);
  }

  /// Invokes the `invite-admin` Edge Function to create a Supabase Auth
  /// user + admin_members row in one shot. The caller (this device) must
  /// be signed in as an admin for the target organisation.
  Future<InviteAdminResult> invite({
    required String email,
    required String password,
    String? fullName,
    String role = 'admin',
  }) async {
    final response = await _client.functions.invoke(
      'invite-admin',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        'role': role,
      },
    );
    final status = response.status;
    final data = response.data;
    if (status != null && status >= 400 && status < 600) {
      final message = data is Map && data['error'] is String
          ? _mapErrorCode(data['error'] as String)
          : 'Invite failed (${status ?? 'unknown'}).';
      throw InviteAdminException(message);
    }
    if (data is! Map ||
        data['user_id'] is! String ||
        data['organization_id'] is! String) {
      throw const InviteAdminException('Unexpected response from server.');
    }
    return InviteAdminResult(
      userId: data['user_id'] as String,
      organizationId: data['organization_id'] as String,
      email: (data['email'] as String?) ?? email,
      role: (data['role'] as String?) ?? role,
    );
  }

  static String _mapErrorCode(String code) {
    switch (code) {
      case 'already_admin':
        return 'That email is already an admin in this organisation.';
      case 'email_in_use':
        return 'An account exists with that email but cannot be added.';
      case 'invalid_email':
        return 'Enter a valid email address.';
      case 'password_too_short':
        return 'Password must be at least 8 characters.';
      case 'forbidden':
        return 'Your account does not have permission to invite admins.';
      case 'owner_required':
        return 'Only an owner can invite another owner.';
      case 'unauthenticated':
        return 'Your session has expired — sign in again.';
      default:
        return 'Invite failed ($code).';
    }
  }
}

class InviteAdminResult {
  const InviteAdminResult({
    required this.userId,
    required this.organizationId,
    required this.email,
    required this.role,
  });

  final String userId;
  final String organizationId;
  final String email;
  final String role;
}

class InviteAdminException implements Exception {
  const InviteAdminException(this.message);
  final String message;
  @override
  String toString() => message;
}
