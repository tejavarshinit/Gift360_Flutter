import 'package:dio/dio.dart';

class GiftingApi {
  final Dio _dio;

  GiftingApi(this._dio);

  Future<Map<String, dynamic>> getMediaUploadUrl(
    String orderItemId,
    String contentType,
  ) async {
    final response = await _dio.post(
      '/media/upload-url',
      data: {'orderItemId': orderItemId, 'contentType': contentType},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scratchVoucher(
    Map<String, dynamic> request,
  ) async {
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

  /// Fetches per-physical-card gift/scratch state for a multi-card order item.
  /// This enables independent scratching/gifting of individual cards when
  /// quantity > 1.
  Future<List<Map<String, dynamic>>> getCardItems(
    String clientId,
    String orderItemId,
  ) async {
    final response = await _dio.get(
      '/coupons/card-items',
      queryParameters: {'clientId': clientId, 'orderItemId': orderItemId},
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }
}
