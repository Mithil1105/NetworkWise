import 'package:flutter/material.dart';

/// Enterprise-oriented color tokens.
///
/// Semantic tokens (success / warning / danger / info / neutral) stay
/// stable across light + dark so chip colours read the same everywhere.
/// Where a widget needs a surface or text colour that *should* adapt to
/// the active brightness, reach for [Theme.of(context).colorScheme]
/// instead — the legacy `surface`, `divider`, etc. constants below are
/// light-mode defaults for widgets that haven't been migrated yet.
class AppColors {
  const AppColors._();

  // Brand / seed — calm, premium indigo-blue. Looks equally good on
  // white surfaces and against dark slate.
  static const Color seed = Color(0xFF2563EB);
  static const Color seedSoft = Color(0xFF60A5FA);
  static const Color seedDeep = Color(0xFF1D4ED8);
  static const Color brandDark = Color(0xFF0B3D91);

  // Accent — warm teal / cyan, used sparingly for "good news" callouts
  // (up-to-date licenses, protected devices, trend deltas in the right
  // direction). Keep separate from the semantic success colour so the
  // dashboard can combine both without chroma conflicts.
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentBg = Color(0xFFCCFBF1);

  // Surfaces (light)
  static const Color surface = Color(0xFFF6F7FB);
  static const Color surfaceElevated = Colors.white;
  static const Color surfaceSunken = Color(0xFFEEF0F4);
  static const Color divider = Color(0xFFE4E7EC);

  // Sidebar — the chrome is always dark regardless of theme so the
  // product stays visually anchored. Slightly richer slate vs. the old
  // values, with a more opinionated selected-row tint.
  static const Color sidebar = Color(0xFF0B1220); // near-black slate
  static const Color sidebarElevated = Color(0xFF111A2E);
  static const Color sidebarHover = Color(0xFF1C2541);
  static const Color sidebarSelected = Color(0xFF2563EB);
  static const Color sidebarSelectedBg = Color(0xFF1A2E52);
  static const Color sidebarText = Color(0xFFD1D5DB);
  static const Color sidebarTextMuted = Color(0xFF94A3B8);

  // Semantic — calibrated against WCAG AA on both white and slate-900
  // backgrounds so chips read well in light + dark.
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutral = Color(0xFF64748B);
  static const Color neutralBg = Color(0xFFE2E8F0);

  // Dark-mode counterparts — elevated card stack with subtle warmth.
  // Slightly desaturated to keep chart colours popping.
  static const Color darkScaffold = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111A2E);
  static const Color darkSurfaceElevated = Color(0xFF182133);
  static const Color darkSurfaceSunken = Color(0xFF0E1627);
  static const Color darkDivider = Color(0xFF1F2B44);
  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Background tints for semantic chips in dark mode — muted, with
  // enough alpha to read on the darkSurface stack without screaming.
  static const Color successBgDark = Color(0xFF14532D);
  static const Color warningBgDark = Color(0xFF7C2D12);
  static const Color dangerBgDark = Color(0xFF7F1D1D);
  static const Color infoBgDark = Color(0xFF1E3A8A);
  static const Color neutralBgDark = Color(0xFF1F2937);
  static const Color accentBgDark = Color(0xFF134E4A);
}
