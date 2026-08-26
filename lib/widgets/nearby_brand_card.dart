import 'package:flutter/material.dart';
import '../core/widgets/brand_image.dart';
import '../features/nearby/data/models/nearby_brand.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NearbyBrandCard extends StatelessWidget {
  final NearbyBrand brand;
  final VoidCallback onBuy;
  const NearbyBrandCard({super.key, required this.brand, required this.onBuy});

  String _getDistanceText() {
    if (brand.nearestDistanceKm < 1) return '${(brand.nearestDistanceKm * 1000).round()} m away';
    return '${brand.nearestDistanceKm.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final imgSrc = brand.resolvedImageUrl ?? '';
    final distance = _getDistanceText();
    final initial = brand.brandName.isNotEmpty ? brand.brandName.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: const Color(0xFFF1F3FB), borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: imgSrc.isNotEmpty
                ? Padding(padding: const EdgeInsets.all(4), child: BrandImage(
                    imageUrl: imgSrc,
                    fit: BoxFit.contain,
                    width: 56,
                    height: 56,
                    errorWidget: (_, __, ___) => _buildAvatar(initial),
                  ))
                : _buildAvatar(initial),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand.brandName, style: AppTextStyles.brandName, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(brand.category, style: AppTextStyles.brandCategory),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_pin, size: 12, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(distance, style: AppTextStyles.brandDistance),
                  ],
                ),
                if (brand.minPrice > 0 || brand.maxPrice > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '₹${brand.minPrice.toInt()}${brand.maxPrice > brand.minPrice ? ' – ₹${brand.maxPrice.toInt()}' : ''}',
                    style: AppTextStyles.brandPrice,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onBuy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: AppColors.primaryShadow, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('Buy', style: AppTextStyles.buyButtonText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEEF0FF), Color(0xFFDDE4FF)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: Text(initial, style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6380)))),
    );
  }
}
