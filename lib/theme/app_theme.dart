import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTokens {
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const double contentMaxWidth = 1280;
  static const double readableMaxWidth = 720;

  static const double railBreakpoint = 900;
  static const double extendedRailBreakpoint = 1200;
}

class AppColors {
  // Brand
  static const primary = Color(0xFF0D9488);
  static const primaryDark = Color(0xFF14B8A6);
  static const accent = Color(0xFF8B5CF6);

  // Status
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Light surfaces
  static const lightBg = Color(0xFFF6F8FB);
  static const lightSurface = Colors.white;
  static const lightBorder = Color(0xFFE6EAF0);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightTextMuted = Color(0xFF94A3B8);

  // Dark surfaces
  static const darkBg = Color(0xFF0B1020);
  static const darkSurface = Color(0xFF111827);
  static const darkSurfaceElevated = Color(0xFF1A2237);
  static const darkBorder = Color(0xFF1F2A44);
  static const darkTextPrimary = Color(0xFFE6EAF2);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted = Color(0xFF64748B);
}

class AppTheme {
  static const String _fontFamily = 'SF Pro Display';

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isDark ? AppColors.primaryDark : AppColors.primary,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      error: AppColors.danger,
    );

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final fillColor = isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      canvasColor: bgColor,
      dividerColor: borderColor,
      textTheme: _textTheme(textPrimary, textSecondary),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: _fontFamily,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF0F172A).withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: _fontFamily,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        elevation: 6,
        focusElevation: 6,
        hoverElevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : textSecondary,
            fontFamily: _fontFamily,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : textSecondary,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          fontFamily: _fontFamily,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textSecondary,
          fontFamily: _fontFamily,
        ),
        useIndicator: true,
        labelType: NavigationRailLabelType.none,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontFamily: _fontFamily,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: _fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: textSecondary),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark ? AppColors.darkBorder : const Color(0xFFE6EAF0),
        circularTrackColor: isDark ? AppColors.darkBorder : const Color(0xFFE6EAF0),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightTextPrimary,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        displayMedium: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        displaySmall: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        headlineSmall: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        titleSmall: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w400, height: 1.45),
        bodySmall: TextStyle(fontFamily: _fontFamily, color: secondary, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontFamily: _fontFamily, color: primary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamily: _fontFamily, color: secondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontFamily: _fontFamily, color: secondary, fontWeight: FontWeight.w500),
      );
}
