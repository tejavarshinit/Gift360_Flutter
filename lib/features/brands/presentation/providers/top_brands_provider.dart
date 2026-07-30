import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/brands/data/models/brand.dart';
import 'package:gift360/features/brands/data/repositories/top_brands_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

final topBrandsApiProvider = Provider<TopBrandsApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return TopBrandsApi(dio);
});

final topBrandsProvider = FutureProvider.autoDispose<List<Brand>>((ref) async {
  final api = ref.watch(topBrandsApiProvider);
  return await api.fetchTopBrands();
});
