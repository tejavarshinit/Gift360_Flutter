import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/brands/data/models/brand_name.dart';
import 'package:gift360/features/brands/data/repositories/brand_names_api.dart';
import 'package:gift360/features/brands/data/repositories/brand_names_repository.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

final brandNamesApiProvider = Provider<BrandNamesApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return BrandNamesApi(dio);
});

final brandNamesRepositoryProvider = Provider<BrandNamesRepository>((ref) {
  final api = ref.watch(brandNamesApiProvider);
  return BrandNamesRepository(api);
});

final brandNamesProvider = FutureProvider.autoDispose<List<BrandName>>((ref) async {
  final repo = ref.watch(brandNamesRepositoryProvider);
  return await repo.getBrandNames();
});
