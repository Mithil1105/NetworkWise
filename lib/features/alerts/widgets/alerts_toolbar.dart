import 'package:flutter/material.dart';

import '../../../core/models/alert.dart';
import '../../../core/theme/app_colors.dart';
import 'severity_filter_chips.dart';

/// The alerts screen toolbar — search field, status filter, category filter,
/// severity chip row, and a live match counter.
class AlertsToolbar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;

  final AlertStatus? statusFilter;
  final ValueChanged<AlertStatus?> onStatusChanged;

  final AlertCategory? categoryFilter;
  final ValueChanged<AlertCategory?> onCategoryChanged;

  final Set<AlertSeverity> selectedSeverities;
  final ValueChanged<AlertSeverity> onSeverityToggle;

  final int matchCount;
  final int totalCount;

  final VoidCallback? onClearAll;

  const AlertsToolbar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.selectedSeverities,
    required this.onSeverityToggle,
    required this.matchCount,
    required this.totalCount,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final filtersApplied = search.isNotEmpty ||
        statusFilter != null ||
        categoryFilter != null ||
        selectedSeverities.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SearchField(value: search, onChanged: onSearchChanged),
                _StatusDropdown(
                  value: statusFilter,
                  onChanged: onStatusChanged,
                ),
                _CategoryDropdown(
                  value: categoryFilter,
                  onChanged: onCategoryChanged,
                ),
                _CountPill(match: matchCount, total: totalCount),
                if (filtersApplied && onClearAll != null)
                  TextButton.icon(
                    onPressed: onClearAll,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.neutral,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SeverityFilterChips(
              selected: selectedSeverities,
              onToggle: onSeverityToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.value, required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 38,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search alerts — title, device, source',
          hintStyle: const TextStyle(fontSize: 12.5),
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.seed, width: 1.2),
          ),
        ),
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final AlertStatus? value;
  final ValueChanged<AlertStatus?> onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DropdownShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AlertStatus?>(
          value: value,
          hint: const Text(
            'All statuses',
            style: TextStyle(fontSize: 12.5),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: TextStyle(
            fontSize: 12.5,
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          items: [
            const DropdownMenuItem<AlertStatus?>(
              value: null,
              child: Text('All statuses'),
            ),
            for (final s in AlertStatus.values)
              DropdownMenuItem<AlertStatus?>(
                value: s,
                child: Text(_label(s)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  static String _label(AlertStatus s) {
    switch (s) {
      case AlertStatus.open:
        return 'Open';
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.resolved:
        return 'Resolved';
    }
  }
}

class _CategoryDropdown extends StatelessWidget {
  final AlertCategory? value;
  final ValueChanged<AlertCategory?> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DropdownShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AlertCategory?>(
          value: value,
          hint: const Text(
            'All categories',
            style: TextStyle(fontSize: 12.5),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: TextStyle(
            fontSize: 12.5,
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          items: [
            const DropdownMenuItem<AlertCategory?>(
              value: null,
              child: Text('All categories'),
            ),
            for (final c in AlertCategory.values)
              DropdownMenuItem<AlertCategory?>(
                value: c,
                child: Text(_label(c)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  static String _label(AlertCategory c) {
    switch (c) {
      case AlertCategory.system:
        return 'System';
      case AlertCategory.network:
        return 'Network';
      case AlertCategory.security:
        return 'Security';
      case AlertCategory.performance:
        return 'Performance';
      case AlertCategory.other:
        return 'Other';
    }
  }
}

class _DropdownShell extends StatelessWidget {
  final Widget child;
  const _DropdownShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _CountPill extends StatelessWidget {
  final int match;
  final int total;

  const _CountPill({required this.match, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.neutralBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Showing $match of $total',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.neutral,
        ),
      ),
    );
  }
}
