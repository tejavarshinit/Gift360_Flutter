import 'package:dio/dio.dart';
import 'package:gift360/features/payment/data/models/payment.dart';

class ValidateOrderApi {
  final Dio _dio;

  ValidateOrderApi(this._dio);

  Future<ValidateOrderResponse> validateOrder(
      String orderNumber, ValidateOrderRequest request) async {
    final response = await _dio.post(
      '/v1/orders/validate/$orderNumber',
      data: request.toJson(),
    );
    return ValidateOrderResponse.fromJson(
        response.data as Map<String, dynamic>);
  }
}
