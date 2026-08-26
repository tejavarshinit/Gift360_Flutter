import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle pageTitle = GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: AppColors.textDarkAlt);
  static TextStyle headerSubtitle = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary);
  static TextStyle searchPlaceholder = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textLight);
  static TextStyle searchText = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF151722));
  static TextStyle categoryChip = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static TextStyle brandName = GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.textDark);
  static TextStyle brandCategory = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted);
  static TextStyle brandDistance = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary);
  static TextStyle brandPrice = GoogleFonts.poppins(fontSize: 10, color: AppColors.textLight);
  static TextStyle buyButtonText = GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle sectionTitle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.textDark);
  static TextStyle countText = GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted);
  static TextStyle loadingText = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted);
  static TextStyle errorText = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280));
  static TextStyle mapLabel = GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary);
  static TextStyle modalTitle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark);
  static TextStyle modalAddress = GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark);
  static TextStyle modalButtonText = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle stateTitle = GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark);
  static TextStyle stateDescription = GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted, height: 1.5);
  static TextStyle stateButtonText = GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);
}
