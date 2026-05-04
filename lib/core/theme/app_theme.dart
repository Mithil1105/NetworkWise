import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material 3 themes for NetworkWise.
///
/// Light mode is intentionally crisp — off-white surface, neutral
/// dividers, premium indigo-blue accent. Dark mode is tuned on a
/// slate/navy stack (not pure black) for the long console sessions
/// IT admins typically run; the card elevation ladder stays visible
/// without resorting to translucent overlays.
class AppTheme {
  const AppTheme._();

  // --------------------------------------------------------------
  // Light
  // --------------------------------------------------------------
  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );

    final colorScheme = baseScheme.copyWith(
      surface: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceSunken,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: AppColors.neutral,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.surface,
      cardColor: AppColors.surfaceElevated,
      cardBorder: AppColors.divider,
      dividerColor: AppColors.divider,
      textPrimary: const Color(0xFF0F172A),
      textSecondary: AppColors.neutral,
      appBarBackground: AppColors.surfaceElevated,
      inputFill: AppColors.surfaceElevated,
      inputBorder: AppColors.divider,
    );
  }

  // --------------------------------------------------------------
  // Dark
  // --------------------------------------------------------------
  static ThemeData get dark {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      surface: AppColors.darkSurface,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      outline: AppColors.darkDivider,
      outlineVariant: AppColors.darkDivider,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      primary: AppColors.seedSoft,
      onPrimary: const Color(0xFF0B1220),
      primaryContainer: const Color(0xFF1E3A8A),
      onPrimaryContainer: AppColors.darkTextPrimary,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkScaffold,
      cardColor: AppColors.darkSurface,
      cardBorder: AppColors.darkDivider,
      dividerColor: AppColors.darkDivider,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      appBarBackground: AppColors.darkSurface,
      inputFill: AppColors.darkSurfaceElevated,
      inputBorder: AppColors.darkDivider,
    );
  }

  // --------------------------------------------------------------
  // Shared builder — keeps the two theme variants in lock-step so a
  // tweak to corner radii / typography / elevation hits both at once.
  // --------------------------------------------------------------
  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color cardBorder,
    required Color dividerColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color appBarBackground,
    required Color inputFill,
    required Color inputBorder,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.comfortable,
      dividerColor: dividerColor,
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cardBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: appBarBackground,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: MaterialStatePropertyAll(
          colorScheme.surfaceContainerHighest.withOpacity(0.6),
        ),
        dividerThickness: 0.5,
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textSecondary,
          letterSpacing: 0.3,
        ),
        dataTextStyle: TextStyle(
          fontSize: 13,
          color: textPrimary,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13.5,
          color: textPrimary,
          height: 1.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cardBorder),
        ),
        textStyle: TextStyle(
          fontSize: 13,
          color: textPrimary,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary.withOpacity(0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          fontSize: 11.5,
          color: cardColor,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardColor,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cardBorder),
        ),
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: cardBorder),
          foregroundColor: textPrimary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: textSecondary),
      textTheme: _textTheme(textPrimary, textSecondary),
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors.fromBrightness(colorScheme.brightness),
      ],
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(color: primary, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: primary, fontWeight: FontWeight.w700),
      displaySmall: TextStyle(color: primary, fontWeight: FontWeight.w700),
      headlineLarge:
          TextStyle(color: primary, fontWeight: FontWeight.w700, height: 1.2),
      headlineMedium:
          TextStyle(color: primary, fontWeight: FontWeight.w700, height: 1.2),
      headlineSmall:
          TextStyle(color: primary, fontWeight: FontWeight.w700, height: 1.2),
      titleLarge:
          TextStyle(color: primary, fontWeight: FontWeight.w700, height: 1.3),
      titleMedium:
          TextStyle(color: primary, fontWeight: FontWeight.w600, height: 1.3),
      titleSmall:
          TextStyle(color: primary, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: TextStyle(color: primary, height: 1.4),
      bodyMedium: TextStyle(color: primary, height: 1.4),
      bodySmall: TextStyle(color: secondary, height: 1.4),
      labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: secondary, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(color: secondary, fontWeight: FontWeight.w600),
    );
  }
}

/// Semantic chip colours exposed as a [ThemeExtension] so widgets can
/// pull context-aware pairs without hand-rolling a `brightness ==` check
/// at every call site. Access via
/// `Theme.of(context).extension<AppSemanticColors>()!`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.danger,
    required this.dangerBg,
    required this.info,
    required this.infoBg,
    required this.neutral,
    required this.neutralBg,
    required this.accent,
    required this.accentBg,
  });

  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color danger;
  final Color dangerBg;
  final Color info;
  final Color infoBg;
  final Color neutral;
  final Color neutralBg;
  final Color accent;
  final Color accentBg;

  factory AppSemanticColors.fromBrightness(Brightness b) {
    final dark = b == Brightness.dark;
    return AppSemanticColors(
      success: AppColors.success,
      successBg: dark ? AppColors.successBgDark : AppColors.successBg,
      warning: AppColors.warning,
      warningBg: dark ? AppColors.warningBgDark : AppColors.warningBg,
      danger: AppColors.danger,
      dangerBg: dark ? AppColors.dangerBgDark : AppColors.dangerBg,
      info: AppColors.info,
      infoBg: dark ? AppColors.infoBgDark : AppColors.infoBg,
      neutral: dark ? AppColors.darkTextSecondary : AppColors.neutral,
      neutralBg: dark ? AppColors.neutralBgDark : AppColors.neutralBg,
      accent: AppColors.accent,
      accentBg: dark ? AppColors.accentBgDark : AppColors.accentBg,
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
    Color? danger,
    Color? dangerBg,
    Color? info,
    Color? infoBg,
    Color? neutral,
    Color? neutralBg,
    Color? accent,
    Color? accentBg,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      neutral: neutral ?? this.neutral,
      neutralBg: neutralBg ?? this.neutralBg,
      accent: accent ?? this.accent,
      accentBg: accentBg ?? this.accentBg,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
    );
  }
}
