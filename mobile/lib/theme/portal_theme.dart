import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light clay auth palette — one system with the rest of the shopping app.
class PortalColors {
  static const Color background = Color(0xFFDFE7DB);
  static const Color surface = Color(0xFFF3F7F1);
  static const Color surfaceSunken = Color(0xFFD2DCCD);
  static const Color primaryDark = Color(0xFF1B3829);
  static const Color primaryMedium = Color(0xFF4A7C59);
  static const Color primaryLight = Color(0xFF8DB89A);
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldLight = Color(0xFFE8C97B);
  static const Color cream = Color(0xFFF4F0E6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF17251D);
  static const Color textBody = Color(0xFF3D4B42);
  static const Color textMuted = Color(0xFF7A8880);
  static const Color error = Color(0xFFC0483A);

  static const Color green950 = Color(0xFF0F1D10);
  static const Color green900 = Color(0xFF122112);
  static const Color green800 = Color(0xFF1A2E1A);
  static const Color green700 = Color(0xFF2D5A2D);
  static const Color textMid = textBody;
  static const Color claySurface = surface;
  static const Color claySunken = surfaceSunken;
  static const Color clayRaised = Color(0xFFF7FAF5);
}

class PortalClay {
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x595A705E),
      offset: Offset(7, 7),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0xFFFFFFFF),
      offset: Offset(-6, -6),
      blurRadius: 14,
    ),
  ];

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x3A5A705E),
      offset: Offset(4, 4),
      blurRadius: 10,
    ),
    BoxShadow(
      color: Color(0xF5FFFFFF),
      offset: Offset(-3, -3),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> primary = [
    BoxShadow(
      color: Color(0x404A7C59),
      offset: Offset(0, 10),
      blurRadius: 20,
    ),
    BoxShadow(
      color: Color(0x66FFFFFF),
      offset: Offset(0, -2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> gold = primary;

  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 26;
}

TextStyle portalDisplay({
  double size = 32,
  FontWeight weight = FontWeight.w800,
  Color color = PortalColors.textDark,
  double height = 1.05,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: -1.0,
  );
}

TextStyle portalBody({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = PortalColors.textBody,
  double height = 1.55,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}
