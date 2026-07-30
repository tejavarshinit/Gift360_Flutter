import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/coupon/data/repositories/coupon_api.dart';

final couponApiProvider = Provider<CouponApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return CouponApi(dio);
});
