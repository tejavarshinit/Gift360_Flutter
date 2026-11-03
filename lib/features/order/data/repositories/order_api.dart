import 'package:dio/dio.dart';

class OrderApi {
  final Dio _dio;

  OrderApi(this._dio);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    final response = await _dio.post('/orders', data: orderData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchOrders(String clientId) async {
    final response = await _dio.post('/orders/json/$clientId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchOrderDetails(String orderNumber) async {
    final response = await _dio.post('/orders/$orderNumber');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateOrderStatus(
      String orderNumber, String status) async {
    final response = await _dio.post('/orders/status', data: {
      'encryptedData': orderNumber,
      'status': status,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Backend-mediated payment initiation (matches React's giftcardApiClient).
  /// `paymentMethod` freezes the DB-backed method fee on the order;
  /// `paymentModes` tells the hosted checkout which modes to offer.
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
    final response = await _dio.post('/orders/$orderNumber/initiate-payment', data: payload);
    return response.data as Map<String, dynamic>;
  }

  /// Juspay UPI-intent: start a payment request (POST
  /// /orders/{orderNumber}/intent/create). Returns the backend-built `deeplink`
  /// — the client only launches it, never builds one itself.
  Future<Map<String, dynamic>> createUpiIntent(String orderNumber) async {
    final response = await _dio.post(
      '/orders/$orderNumber/intent/create',
      data: <String, dynamic>{},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Poll the backend-verified intent status (POST
  /// /orders/{orderNumber}/intent/status). The client only DISPLAYS what the
  /// backend reports — it never decides that a payment is done.
  Future<Map<String, dynamic>> fetchUpiIntentStatus(String orderNumber) async {
    final response = await _dio.post(
      '/orders/$orderNumber/intent/status',
      data: <String, dynamic>{},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Retry payment for an existing PENDING order (matches React's
  /// `initiateRetryPayment` in paymentApi.ts — POST /orders/{orderNumber}/retry-payment
  /// with body { walletUsed, walletAmount, earnCashback, paymentMethod, paymentModes }).
  Future<Map<String, dynamic>> retryPayment(
    String orderNumber, {
    required bool walletUsed,
    required double walletAmount,
    required bool earnCashback,
    String? paymentMethod,
    List<String>? paymentModes,
  }) async {
    final hasList = paymentModes != null && paymentModes.isNotEmpty;
    final response = await _dio.post('/orders/$orderNumber/retry-payment', data: {
      'walletUsed': walletUsed,
      'walletAmount': walletAmount,
      'earnCashback': earnCashback,
      if (paymentMethod != null && paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
      if (hasList) 'paymentModes': paymentModes,
    });
    return response.data as Map<String, dynamic>;
  }
}
