import 'package:flutter/foundation.dart';

/// One fixed disk volume on a Windows endpoint — captured by the probe
/// from `Win32_LogicalDisk` (DriveType=3). The Dashboard renders one
/// `_MetricBar` per volume so admins see C: / D: / E: separately,
/// instead of the old aggregated `disk_total_gb` summary.
@immutable
class DiskVolume {
  /// Drive letter — e.g. `C:`. Empty when the drive isn't mounted to
  /// a letter (rare on Windows workstations).
  final String drive;

  /// Total capacity in GB.
  final double totalGb;

  /// Used space in GB. Always non-negative — clamped to `totalGb` if
  /// the probe somehow reports more used than total.
  final double usedGb;

  /// Volume label — e.g. "Windows", "Backups", "Data". Empty if the
  /// user never set one.
  final String label;

  /// File system — e.g. NTFS / exFAT. Useful for Quick-glance triage
  /// (an exFAT volume in a CA firm probably means a USB-attached
  /// archive disk).
  final String fileSystem;

  const DiskVolume({
    required this.drive,
    required this.totalGb,
    required this.usedGb,
    this.label = '',
    this.fileSystem = '',
  });

  double get freeGb {
    final v = totalGb - usedGb;
    return v < 0 ? 0 : v;
  }

  double get usagePercent =>
      totalGb == 0 ? 0 : (usedGb / totalGb * 100.0).clamp(0, 100).toDouble();

  /// Display label combining the drive letter with the volume label,
  /// e.g. `C: — Windows`. Falls back to just the drive letter when
  /// no volume label is set.
  String get displayName {
    final trimmed = label.trim();
    if (drive.isEmpty) return trimmed.isEmpty ? 'Unknown disk' : trimmed;
    if (trimmed.isEmpty) return drive;
    return '$drive — $trimmed';
  }

  factory DiskVolume.fromJson(Map<String, dynamic> json) {
    final total = (json['total_gb'] as num?)?.toDouble() ?? 0;
    final freeRaw = (json['free_gb'] as num?)?.toDouble();
    final usedRaw = (json['used_gb'] as num?)?.toDouble();
    final used = usedRaw ??
        (freeRaw != null ? (total - freeRaw).clamp(0, total).toDouble() : 0);
    return DiskVolume(
      drive: (json['drive'] as String?) ?? '',
      totalGb: total,
      usedGb: used,
      label: (json['label'] as String?) ?? '',
      fileSystem: (json['file_system'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'drive': drive,
        'total_gb': totalGb,
        'used_gb': usedGb,
        'free_gb': freeGb,
        if (label.isNotEmpty) 'label': label,
        if (fileSystem.isNotEmpty) 'file_system': fileSystem,
      };
}
