import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/order/data/repositories/order_api.dart';
import 'package:gift360/features/order/data/repositories/validate_order_api.dart';

final orderApiProvider = Provider<OrderApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return OrderApi(dio);
});

final validateOrderApiProvider = Provider<ValidateOrderApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return ValidateOrderApi(dio);
});
