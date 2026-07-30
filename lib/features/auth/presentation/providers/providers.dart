import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gift360/core/network/dio_client.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/auth/data/repositories/auth_api.dart';
import 'package:gift360/features/auth/data/repositories/auth_repository.dart';

final dioProvider = Provider<Dio>((ref) {
  final client = DioClient(
    baseUrl: AppConfig.authApiUrl,
    secureStorage: const FlutterSecureStorage(),
  );
  return client.dio;
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(authApi: ref.watch(authApiProvider));
});

final brandsDioProvider = Provider<Dio>((ref) {
  final client = DioClient(
    baseUrl: AppConfig.brandApiUrl,
    secureStorage: const FlutterSecureStorage(),
  );
  return client.dio;
});

final giftcardDioProvider = Provider<Dio>((ref) {
  final client = DioClient(
    baseUrl: AppConfig.couponApiUrl,
    secureStorage: const FlutterSecureStorage(),
  );
  return client.dio;
});

final paymentDioProvider = Provider<Dio>((ref) {
  final client = DioClient(
    baseUrl: AppConfig.paymentApiUrl,
    secureStorage: const FlutterSecureStorage(),
  );
  return client.dio;
});

