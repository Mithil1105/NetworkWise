import 'package:flutter/foundation.dart';

enum AlertSeverity { info, low, medium, high, critical }

enum AlertStatus { open, acknowledged, resolved }

enum AlertCategory { system, network, security, performance, other }

AlertSeverity _parseSeverity(Object? v) {
  return AlertSeverity.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AlertSeverity.info,
  );
}

AlertStatus _parseStatus(Object? v) {
  return AlertStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AlertStatus.open,
  );
}

AlertCategory _parseCategory(Object? v) {
  return AlertCategory.values.firstWhere(
    (e) => e.name == v,
    orElse: () => AlertCategory.other,
  );
}

/// A single alert / notification surfaced in the dashboard.
@immutable
class Alert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final AlertStatus status;
  final AlertCategory category;
  final DateTime timestamp;
  final String? deviceId;
  final String? source;

  const Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.status,
    required this.category,
    required this.timestamp,
    this.deviceId,
    this.source,
  });

  Alert copyWith({
    String? id,
    String? title,
    String? message,
    AlertSeverity? severity,
    AlertStatus? status,
    AlertCategory? category,
    DateTime? timestamp,
    String? deviceId,
    String? source,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
      source: source ?? this.source,
    );
  }

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String? ?? '',
        severity: _parseSeverity(json['severity']),
        status: _parseStatus(json['status']),
        category: _parseCategory(json['category']),
        timestamp: DateTime.parse(json['timestamp'] as String),
        deviceId: json['deviceId'] as String?,
        source: json['source'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'severity': severity.name,
        'status': status.name,
        'category': category.name,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'source': source,
      };

  factory Alert.mock({
    String id = 'alrt-001',
    AlertSeverity severity = AlertSeverity.medium,
    AlertStatus status = AlertStatus.open,
    AlertCategory category = AlertCategory.security,
  }) {
    return Alert(
      id: id,
      title: 'Antivirus signatures outdated',
      message:
          'Windows Defender signatures were last updated more than 48 hours ago.',
      severity: severity,
      status: status,
      category: category,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      deviceId: 'dev-001',
      source: 'Defender',
    );
  }
}
