import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LocationPrompt extends StatelessWidget {
  final VoidCallback onRequest;
  const LocationPrompt({super.key, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.navigation, color: AppColors.primary, size: 32)),
          const SizedBox(height: 16),
          Text('Enable Location', style: AppTextStyles.stateTitle),
          const SizedBox(height: 8),
          Text('We need your location to find gift voucher stores near you.', style: AppTextStyles.stateDescription, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRequest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_pin, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Allow Location Access', style: AppTextStyles.stateButtonText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationDenied extends StatelessWidget {
  const LocationDenied({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.red50, shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: AppColors.red400, size: 32)),
          const SizedBox(height: 16),
          Text('Location Access Denied', style: AppTextStyles.stateTitle),
          const SizedBox(height: 8),
          Text('Please enable location access in your browser settings to discover stores near you.', style: AppTextStyles.stateDescription, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String category;
  const EmptyState({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.store, color: AppColors.primary, size: 32)),
          const SizedBox(height: 16),
          Text('No Stores Found', style: AppTextStyles.stateTitle),
          const SizedBox(height: 8),
          Text('No $category stores found near your location. Try a different category.', style: AppTextStyles.stateDescription, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
