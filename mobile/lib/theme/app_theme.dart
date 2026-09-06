import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Claymorphism: surfaces sit just a shade off the background and are lifted by
/// a pair of shadows - dark below-right, light above-left - so they read as
/// soft pressed clay rather than cards floating on a page. Borders do almost
/// no work here; the light does it.
///
/// That is why the surface and background colours are so close. Pushing them
/// apart turns every element back into a flat card and the effect collapses.
class AppColors {
  // Grounds
  static const Color background = Color(0xFFE8EDE6);
  static const Color surface = Color(0xFFF2F5F0);
  static const Color surfaceSunken = Color(0xFFDFE5DC);

  // Brand
  static const Color primaryDark = Color(0xFF1B3829);
  static const Color primaryMedium = Color(0xFF4A7C59);
  static const Color primaryLight = Color(0xFF8DB89A);
  static const Color accent = Color(0xFFC9A96E);

  // Ink
  static const Color textDark = Color(0xFF17251D);
  static const Color textBody = Color(0xFF3D4B42);
  static const Color textMuted = Color(0xFF7A8880);

  // Meaning, kept apart from the brand green
  static const Color error = Color(0xFFC0483A);
  static const Color success = Color(0xFF3F7D53);
  static const Color warning = Color(0xFFB8832F);

  // Clay lighting
  static const Color shadowDark = Color(0x33667A6C);
  static const Color shadowLight = Color(0xF2FFFFFF);

  // Kept so older screens keep compiling while they are moved over.
  static const Color border = Color(0xFFD3DBD0);
  static const Color inputFill = Color(0xFFEDF1EA);
}

/// One radius scale. Clay wants generous curves - anything under ~16 reads as
/// a flat chip no matter how the shadows are set.
class AppRadius {
  static const double sm = 16;
  static const double md = 22;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;
}

class AppShadows {
  /// Raised: the default for anything that sits on top of the page.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: AppColors.shadowDark,
      offset: Offset(6, 6),
      blurRadius: 14,
    ),
    BoxShadow(
      color: AppColors.shadowLight,
      offset: Offset(-5, -5),
      blurRadius: 12,
    ),
  ];

  /// Softer, for elements repeated many times down a list, where the full
  /// treatment turns into visual noise.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x22667A6C),
      offset: Offset(4, 4),
      blurRadius: 10,
    ),
    BoxShadow(
      color: Color(0xCCFFFFFF),
      offset: Offset(-3, -3),
      blurRadius: 8,
    ),
  ];

  /// For the primary green, whose own colour carries the weight.
  static const List<BoxShadow> accent = [
    BoxShadow(
      color: Color(0x384A7C59),
      offset: Offset(0, 8),
      blurRadius: 18,
    ),
  ];
}

TextTheme _buildTextTheme(TextTheme base) {
  // Plus Jakarta Sans: geometric enough to read as modern, with round
  // terminals that agree with the soft shapes instead of fighting them.
  final text = GoogleFonts.plusJakartaSansTextTheme(base);

  return text.copyWith(
    displayLarge: text.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: AppColors.textDark,
    ),
    headlineLarge: text.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: AppColors.textDark,
    ),
    headlineMedium: text.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: AppColors.textDark,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppColors.textDark,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    ),
    bodyLarge: text.bodyLarge?.copyWith(color: AppColors.textBody, height: 1.5),
    bodyMedium: text.bodyMedium?.copyWith(color: AppColors.textBody, height: 1.5),
    bodySmall: text.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryMedium,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      error: AppColors.error,
    ),
    textTheme: _buildTextTheme(base.textTheme),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textDark,
      ),
    ),
    // Inputs are pressed into the page rather than raised off it, which is the
    // half of claymorphism that says "you can type here".
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primaryMedium, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      insetPadding: const EdgeInsets.all(16),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFD7DED4),
      thickness: 1,
      space: 1,
    ),
  );
}
