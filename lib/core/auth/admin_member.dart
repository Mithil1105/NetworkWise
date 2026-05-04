import 'package:flutter/foundation.dart';

/// Row from `admin_members` — denormalised with the caller's org id so
/// the dashboard knows which tenant to scope its reads to.
@immutable
class AdminMember {
  const AdminMember({
    required this.userId,
    required this.organizationId,
    required this.email,
    required this.role,
    this.fullName,
  });

  final String userId;
  final String organizationId;
  final String email;
  final String role; // 'admin' | 'owner'
  final String? fullName;

  factory AdminMember.fromRow({
    required Map<String, dynamic> row,
    required String email,
  }) {
    return AdminMember(
      userId: row['user_id'] as String,
      organizationId: row['organization_id'] as String,
      email: email,
      role: (row['role'] as String?) ?? 'admin',
      fullName: row['full_name'] as String?,
    );
  }
}
