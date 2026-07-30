import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/guard_rails/data/repositories/guard_rails_api.dart';

final guardRailsApiProvider = Provider<GuardRailsApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return GuardRailsApi(dio);
});
