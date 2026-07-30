import 'package:dio/dio.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/payment/data/models/payment.dart';

class PaymentApi {
  final Dio _dio;

  PaymentApi(this._dio);

  String _generateTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<TokenGenerationResponse> generateToken(String merchantOrderRef) async {
    final response = await _dio.post('/token', data: {
      'sabbpe_userid': AppConfig.sabbpeUserId,
      'sabbpe_merchantid': AppConfig.sabbpeMerchantId,
      'sabbpe_password': AppConfig.sabbpePassword,
      'timestamp': _generateTimestamp(),
      'merchant_order_ref': merchantOrderRef,
    });
    return TokenGenerationResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SabbPeInitiateResponse> initiatePayment(SabbPeInitiateRequest request) async {
    final response = await _dio.post('/initiate', data: request.toJson());
    return SabbPeInitiateResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> initiatePaymentProcess(Map<String, dynamic> payload) async {
    final response = await _dio.post('/PaymentProcess', data: payload);
    return response.data as Map<String, dynamic>;
  }
}
