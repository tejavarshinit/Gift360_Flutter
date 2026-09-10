import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/data/repositories/brands_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

final brandsApiProvider = Provider<BrandsApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return BrandsApi(dio);
});

final brandsProvider = FutureProvider.autoDispose<List<Brand>>((ref) async {
  final api = ref.watch(brandsApiProvider);
  return await api.getBrands();
});

final brandDetailsProvider = FutureProvider.family.autoDispose<Brand, String>((ref, brandId) async {
  final api = ref.watch(brandsApiProvider);
  return await api.getBrandDetails(brandId);
});

/// Fetch brand details via POST /brands/{brandId} (matches React's useBrandDetails).
/// Used by SuperCoin conversion screen which needs supercoinMultiplier.
final brandDetailsByIdProvider = FutureProvider.family.autoDispose<Brand, String>((ref, brandId) async {
  final api = ref.watch(brandsApiProvider);
  return await api.getBrandDetailsById(brandId);
});

final brandSearchProvider = FutureProvider.family.autoDispose<List<Brand>, String>((ref, query) async {
  final api = ref.watch(brandsApiProvider);
  return await api.searchBrands(query);
});

final allBrandsProvider = FutureProvider.autoDispose<List<Brand>>((ref) async {
  final api = ref.watch(brandsApiProvider);
  return await api.getBrandsWithCategory();
});

class FilterKey {
  final List<String> categories;
  final List<String> brands;
  final double? minPrice;
  final double? maxPrice;
  final String sortBy;
  final List<String> discountRanges;

  const FilterKey({
    required this.categories,
    required this.brands,
    this.minPrice,
    this.maxPrice,
    required this.sortBy,
    required this.discountRanges,
  });

  Map<String, dynamic> toJson() => {
        'categories': categories,
        'brands': brands,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'sortBy': sortBy,
        'discountRanges': discountRanges,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterKey &&
          listEq(categories, other.categories) &&
          listEq(brands, other.brands) &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          sortBy == other.sortBy &&
          listEq(discountRanges, other.discountRanges);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(categories),
        Object.hashAll(brands),
        minPrice,
        maxPrice,
        sortBy,
        Object.hashAll(discountRanges),
      );

  static bool listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final filteredBrandsProvider = FutureProvider.autoDispose.family<List<Brand>, FilterKey>((ref, filter) async {
  final api = ref.watch(brandsApiProvider);
  return await api.getFilteredBrandsList(filter.toJson());
});
