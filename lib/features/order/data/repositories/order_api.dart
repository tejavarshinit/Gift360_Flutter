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
  /// The backend owns merchant credentials and computes the net payable.
  Future<Map<String, dynamic>> initiateBackendPayment(String orderNumber) async {
    final response = await _dio.post('/orders/$orderNumber/initiate-payment');
    return response.data as Map<String, dynamic>;
  }
}
