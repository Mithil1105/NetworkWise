/// Lightweight display formatters. Dependency-free so this module
/// compiles on a fresh `pubspec.yaml` without extra packages.
class Formatters {
  const Formatters._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Formats as `yyyy-MM-dd HH:mm`.
  static String dateTime(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${_two(d.month)}-${_two(d.day)} '
        '${_two(d.hour)}:${_two(d.minute)}';
  }

  /// Formats as `yyyy-MM-dd`.
  static String dateOnly(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  /// Human-friendly relative time — `2m ago`, `3h ago`, `Yesterday`.
  static String relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateOnly(dt);
  }

  /// Binary byte formatter — `1.5 GB`.
  static String bytes(num b) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var v = b.toDouble();
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String percent(num v, {int fractionDigits = 0}) =>
      '${v.toStringAsFixed(fractionDigits)}%';

  /// `3d 4h`, `2h 10m`, `45m`, `30s`.
  static String uptime(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
