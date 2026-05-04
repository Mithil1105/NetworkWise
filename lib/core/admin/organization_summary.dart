import 'package:flutter/foundation.dart';

/// Snapshot of the caller's organisation — kept deliberately small so it
/// can be refreshed cheaply after every rotate/rename without pulling
/// down unrelated fields.
@immutable
class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.enrollmentCode,
    required this.enrollmentCodeRotatedAt,
    required this.createdAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? enrollmentCode;
  final DateTime? enrollmentCodeRotatedAt;
  final DateTime createdAt;

  OrganizationSummary copyWith({
    String? enrollmentCode,
    DateTime? enrollmentCodeRotatedAt,
  }) {
    return OrganizationSummary(
      id: id,
      slug: slug,
      name: name,
      enrollmentCode: enrollmentCode ?? this.enrollmentCode,
      enrollmentCodeRotatedAt:
          enrollmentCodeRotatedAt ?? this.enrollmentCodeRotatedAt,
      createdAt: createdAt,
    );
  }

  factory OrganizationSummary.fromRow(Map<String, dynamic> row) {
    DateTime? parseTs(Object? raw) =>
        raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

    return OrganizationSummary(
      id: row['id'] as String,
      slug: (row['slug'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      enrollmentCode: row['enrollment_code'] as String?,
      enrollmentCodeRotatedAt: parseTs(row['enrollment_code_rotated_at']),
      createdAt: parseTs(row['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}
