import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (matching React #523da9, #4c42b8, #5365df)
  static const Color primaryPurple = Color(0xFF523DA9);
  static const Color primaryPurpleDark = Color(0xFF4C42B8);
  static const Color primaryBlue = Color(0xFF5365DF);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPurple, primaryPurpleDark, primaryBlue],
  );

  // Accent / Gold
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFF5D77A);

  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF3F5F9);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x14000000);

  // Text
  static const Color textPrimary = Color(0xFF101010);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF888888);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFB42318);
  static const Color errorBg = Color(0xFFFEE4E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Bottom Nav
  static const Color navActive = Color(0xFF10AEEC);
  static const Color navInactive = Color(0xFF092F82);

  // Action Grid
  static const Color actionIconBg = Color(0xFFF1F2F8);
  static const Color actionIconColor = Color(0xFF092A92);

  // Profile Avatar
  static const Color profileAvatarBg = Color(0xFFE99DA8);

  // Balance Card
  static const Color balanceCardBg = Color(0x33FFFFFF); // white 20%
  static const Color balanceCardBorder = Color(0x59FFFFFF); // white 35%
  static const Color balanceCardShadow = Color(0x3D19194B); // rgba(27,25,75,0.24)

  // Buy Button Gradient
  static const LinearGradient buyButtonGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
  );

  // Search
  static const Color searchBorder = Color(0xFFE5E7EB);

  // Divider
  static const Color divider = Color(0xFFE5E7EB);

  // Category Filter
  static const Color categoryFilterBg = Color(0xFF5B43C9);

  // Sheet
  static const Color sheetBg = Color(0xFFF4F5FA);

  // Gift Watermark
  static const Color giftWatermark = Color(0x295B5B72); // #5B5B72 at 16%

  // Brand Card
  static const Color brandCardText = Color(0xFF101010);
  static const Color brandCardMeta = Color(0xFF888888);

  // Shimmer / Skeleton
  static const Color shimmerBase = Color(0xFFE5E7EB);
  static const Color shimmerHighlight = Color(0xFFF3F4F6);

  // Legacy
  static const Color purpleLight = Color(0xFF5343B2);
}
