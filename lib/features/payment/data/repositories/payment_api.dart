import 'package:dio/dio.dart';

class PaymentApi {
  final Dio _dio;

  PaymentApi(this._dio);

  /// Backend-mediated payment initiation.
  /// The backend owns the merchant credentials and computes the net payable,
  /// so the frontend never sends an amount or token to the gateway directly.
  /// `paymentMethod` freezes the DB-backed method fee on the order; `paymentModes`
  /// tells the hosted checkout which modes to offer (matches React).
  Future<Map<String, dynamic>> initiateBackendPayment(
    String orderNumber, {
    String? paymentMethod,
    List<String>? paymentModes,
  }) async {
    final hasList = paymentModes != null && paymentModes.isNotEmpty;
    final payload = (paymentMethod != null && paymentMethod.isNotEmpty) || hasList
        ? <String, dynamic>{
            if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
            if (hasList) 'paymentModes': paymentModes,
          }
        : null;
    final response = await _dio.post(
      '/orders/$orderNumber/initiate-payment',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }
}
