import 'package:flutter/material.dart';

/// Typed model for a sidebar entry.
@immutable
class AppNavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AppNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
