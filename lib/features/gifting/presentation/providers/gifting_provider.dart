import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/gifting/data/repositories/gifting_api.dart';

final giftingApiProvider = Provider<GiftingApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return GiftingApi(dio);
});
