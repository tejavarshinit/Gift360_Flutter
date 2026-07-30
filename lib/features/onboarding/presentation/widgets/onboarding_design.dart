import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingDesign {
  OnboardingDesign._();

  // Colors
  static const Color primary = Color(0xFF7C3AED);
  static const Color primarySoft = Color(0xFFEDE9FE);
  static const Color foreground = Color(0xFF1A1A1A);
  static const Color mutedForeground = Color(0xFF808080);
  static const Color background = Colors.white;
  static const Color border = Color(0xFFEBEBEB);

  // Shadows
  static const List<BoxShadow> shadowCardSoft = [
    BoxShadow(
      color: Color(0x2E3F2D4D),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -8,
    ),
  ];
  static const List<BoxShadow> shadowTile = [
    BoxShadow(
      color: Color(0x1F192020),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: -6,
    ),
  ];

  // Text Styles
  static TextStyle poppins({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = foreground,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // Brand names for splash columns
  static const List<String> brandNames = [
    'puma', 'bata', 'levis', 'tego', 'tatacliq',
    'ajio', 'raymond', 'fastrack', 'flipkart', 'amazon',
    'myntra', 'woodland', 'nike', 'zomato',
  ];
}
