import 'package:dio/dio.dart';
import 'package:gift360/features/checkout_gate/data/device_id.dart';
import 'package:gift360/features/checkout_gate/data/models/checkout_models.dart';

/// Checkout requirements + email verification APIs (`/api/v1/...` on brand host).
class CheckoutApi {
  final Dio _dio;

  CheckoutApi(this._dio);

  Future<CheckoutRequirements> fetchRequirements({
    required String orderNumber,
    required String paymentMethod,
  }) async {
    final response = await _dio.get(
      '/v1/checkout/requirements',
      queryParameters: {
        'orderNumber': orderNumber,
        'paymentMethod': paymentMethod,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return CheckoutRequirements.fromJson(data);
    }
    if (data is Map) {
      return CheckoutRequirements.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Unexpected checkout requirements response');
  }

  Future<EmailCheckResult> checkEmail(String email) async {
    final response = await _dio.post(
      '/v1/email/check',
      data: {'email': email},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return EmailCheckResult.fromJson(data);
    if (data is Map) {
      return EmailCheckResult.fromJson(Map<String, dynamic>.from(data));
    }
    return const EmailCheckResult(ok: true, block: false);
  }

  Future<void> sendEmailVerificationCode({String? email}) async {
    final deviceId = await getOrCreateDeviceId();
    await _dio.post(
      '/v1/email/verification/send',
      data: {
        if (email != null && email.isNotEmpty) 'email': email,
      },
      options: Options(headers: {'X-Device-Id': deviceId}),
    );
  }

  Future<void> confirmEmailVerificationCode(String code) async {
    final deviceId = await getOrCreateDeviceId();
    await _dio.post(
      '/v1/email/verification/confirm',
      data: {'code': code},
      options: Options(headers: {'X-Device-Id': deviceId}),
    );
  }
}
