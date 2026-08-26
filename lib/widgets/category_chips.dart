import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CategoryChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const CategoryChips({super.key, required this.selected, required this.onSelect});

  static const categories = ['Entertainment', 'Ecommerce', 'Fashion & Lifestyle', 'Food & Beverages', 'Jewellery', 'Gaming'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final active = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? [BoxShadow(color: AppColors.primary.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8))] : [],
              ),
              child: Text(cat, style: AppTextStyles.categoryChip.copyWith(color: active ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
