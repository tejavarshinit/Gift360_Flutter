import 'package:dio/dio.dart';

class PaymentApi {
  final Dio _dio;

  PaymentApi(this._dio);

  /// Backend-mediated payment initiation.
  /// The backend owns the merchant credentials and computes the net payable,
  /// so the frontend never sends an amount or token to the gateway directly.
  /// This is the primary payment flow used in the React reference project.
  Future<Map<String, dynamic>> initiateBackendPayment(String orderNumber) async {
    final response = await _dio.post('/orders/$orderNumber/initiate-payment');
    return response.data as Map<String, dynamic>;
  }
}
