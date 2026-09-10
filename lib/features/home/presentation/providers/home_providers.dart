import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';

/// Fetches personalized brand recommendations for the user.
final personalRecommendationsProvider = FutureProvider<List<Brand>>((ref) async {
  final api = ref.watch(brandsApiProvider);
  try {
    return await api.getPersonalRecommendations();
  } catch (_) {
    return [];
  }
});

/// Fetches available occasion categories.
final occasionsProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(brandsApiProvider);
  try {
    return await api.getOccasions();
  } catch (_) {
    return [];
  }
});

/// Fetches brands for a specific occasion using POST /v1/fetchbrands with
/// {occasion: value}, matching the React dynamic occasion sections.
final occasionRecommendationsProvider =
    FutureProvider.family<List<Brand>, String>((ref, occasion) async {
  final api = ref.watch(brandsApiProvider);
  try {
    return await api.getRecommendations(occasion);
  } catch (_) {
    return [];
  }
});

/// Fetches live platform fee configuration.
final platformFeeConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(brandsApiProvider);
  try {
    return await api.getPlatformFeeConfig();
  } catch (_) {
    // Match React Cart.tsx defaults (feePercent 0.02, feeMax 20).
    return {'feePercent': 0.02, 'feeMax': 20.0};
  }
});
