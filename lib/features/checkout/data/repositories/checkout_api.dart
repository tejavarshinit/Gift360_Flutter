import 'package:dio/dio.dart';

import 'package:gift360/features/checkout/data/models/checkout_models.dart';

class CheckoutApi {
  final Dio _dio;

  const CheckoutApi(this._dio);

  Future<CheckoutRequirements> getRequirements({
    String? orderNumber,
    String? paymentMethod,
  }) async {
    final response = await _dio.get(
      '/v1/checkout/requirements',
      queryParameters: {
        if (orderNumber != null && orderNumber.isNotEmpty)
          'orderNumber': orderNumber,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'paymentMethod': paymentMethod,
      },
    );
    return CheckoutRequirements.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }

  Future<Map<String, dynamic>> sendEmailCode({required String deviceId}) async {
    try {
      final response = await _dio.post(
        '/v1/email/verification/send',
        data: {'deviceId': deviceId},
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['status'] != null) {
        return body.cast<String, dynamic>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmEmailCode({required String code}) async {
    try {
      final response = await _dio.post(
        '/v1/email/verification/confirm',
        data: {'code': code},
      );
      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['status'] != null) {
        return body.cast<String, dynamic>();
      }
      rethrow;
    }
  }

  Future<EmailCheckResult> checkEmail(String email) async {
    final response = await _dio.post('/v1/email/check', data: {'email': email});
    return EmailCheckResult.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}
