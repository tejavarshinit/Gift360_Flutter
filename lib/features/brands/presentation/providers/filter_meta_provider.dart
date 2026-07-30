import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';

class FilterMeta {
  final List<String> categories;
  final List<String> brands;
  final List<PriceRange> priceRanges;
  final List<DiscountRange> discountRanges;
  final List<String> sortOptions;

  const FilterMeta({
    this.categories = const [],
    this.brands = const [],
    this.priceRanges = const [],
    this.discountRanges = const [],
    this.sortOptions = const ['Popularity'],
  });

  factory FilterMeta.fromJson(Map<String, dynamic> json) {
    return FilterMeta(
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      brands: (json['brands'] as List?)?.map((e) => e.toString()).toList() ?? [],
      priceRanges: (json['priceRanges'] as List?)
              ?.map((e) => PriceRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      discountRanges: (json['discountRanges'] as List?)
              ?.map((e) => DiscountRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sortOptions: (json['sortOptions'] as List?)?.map((e) => e.toString()).toList() ?? ['Popularity'],
    );
  }
}

class PriceRange {
  final String label;
  final double? min;
  final double? max;

  const PriceRange({required this.label, this.min, this.max});

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      label: json['label'] as String? ?? '',
      min: (json['min'])?.toDouble(),
      max: (json['max'])?.toDouble(),
    );
  }
}

class DiscountRange {
  final String label;
  final String value;

  const DiscountRange({required this.label, required this.value});

  factory DiscountRange.fromJson(Map<String, dynamic> json) {
    return DiscountRange(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

final filterMetaProvider = FutureProvider.autoDispose<FilterMeta>((ref) async {
  final api = ref.watch(brandsApiProvider);
  final data = await api.getFilterMeta();
  return FilterMeta.fromJson(data);
});
