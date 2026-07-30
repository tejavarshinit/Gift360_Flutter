import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/stores/data/repositories/stores_api.dart';

final storesApiProvider = Provider<StoresApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return StoresApi(dio);
});
