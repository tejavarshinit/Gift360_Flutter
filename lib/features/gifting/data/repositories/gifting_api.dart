import 'package:dio/dio.dart';

class GiftingApi {
  final Dio _dio;

  GiftingApi(this._dio);

  Future<Map<String, dynamic>> getMediaUploadUrl(
      String orderItemId, String contentType) async {
    final response = await _dio.post('/media/upload-url', data: {
      'orderItemId': orderItemId,
      'contentType': contentType,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scratchVoucher(Map<String, dynamic> request) async {
    final response = await _dio.post('/coupons/scratch', data: request);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> giftVoucher(Map<String, dynamic> request) async {
    final response = await _dio.post('/coupons/gift', data: request);
    return response.data as Map<String, dynamic>;
  }

  /// GET /v1/voucher/balance-check?cardNo={cardNo}
  /// Returns: { balance: string, status: "ACTIVE"|"USED" }
  Future<Map<String, dynamic>> checkVoucherBalance(String cardNo) async {
    final response = await _dio.get(
      '/v1/voucher/balance-check',
      queryParameters: {'cardNo': cardNo},
    );
    return response.data as Map<String, dynamic>;
  }
}
