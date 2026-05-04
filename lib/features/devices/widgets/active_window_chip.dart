import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// Compact pill that shows the foreground window title + owning process
/// of an endpoint. Designed to live inline next to the device's status
/// chips so admins can see, at a glance, what the user is working on
/// right now.
///
/// Falls back to a neutral "Idle / locked" state when the probe didn't
/// see a foreground window at the latest tick — that's the normal
/// situation when the screen is locked or the app runs as a session-0
/// service. Stale entries (older than `staleAfter`) are de-emphasised
/// with a "stale" hint so the operator doesn't mistake them for
/// real-time activity.
class ActiveWindowChip extends StatelessWidget {
  const ActiveWindowChip({
    super.key,
    required this.title,
    required this.processName,
    required this.seenAt,
    this.compact = false,
    this.staleAfter = const Duration(minutes: 5),
  });

  /// Window title — `null` when foreground was undefined at the last tick.
  final String? title;

  /// Owning process .exe — e.g. `EXCEL.EXE`, `chrome.exe`. Optional.
  final String? processName;

  /// Server-stamped time the window was last refreshed.
  final DateTime? seenAt;

  /// `true` renders a single-line, narrower pill suitable for table cells.
  final bool compact;

  /// Anything older than this gets visually de-emphasised.
  final Duration staleAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = title?.trim();
    final hasTitle = t != null && t.isNotEmpty;

    final isStale = seenAt != null &&
        DateTime.now().toUtc().difference(seenAt!.toUtc()) > staleAfter;

    final iconColor = !hasTitle
        ? AppColors.neutral
        : (isStale ? AppColors.neutral : AppColors.info);
    final fg = !hasTitle
        ? AppColors.neutral
        : (isStale
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface);
    final bg = !hasTitle
        ? AppColors.neutralBg
        : (isStale ? AppColors.neutralBg : AppColors.infoBg);

    final headline = !hasTitle ? 'Idle / locked' : t;
    final subline = !hasTitle
        ? (seenAt == null
            ? 'No activity seen yet'
            : 'Locked ${Formatters.relative(seenAt!)}')
        : _composeSubline(processName, seenAt, isStale);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      constraints: BoxConstraints(
        maxWidth: compact ? 280 : 420,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            hasTitle ? Icons.desktop_windows_outlined : Icons.lock_outline,
            size: compact ? 14 : 16,
            color: iconColor,
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: compact
                ? Text(
                    headline,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headline,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          height: 1.2,
                        ),
                      ),
                      if (subline != null && subline.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subline,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String? _composeSubline(
    String? processName,
    DateTime? seenAt,
    bool isStale,
  ) {
    final parts = <String>[];
    if (processName != null && processName.trim().isNotEmpty) {
      parts.add(processName.trim());
    }
    if (seenAt != null) {
      parts.add(
        isStale
            ? '— last seen ${Formatters.relative(seenAt)}'
            : '— seen ${Formatters.relative(seenAt)}',
      );
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}
