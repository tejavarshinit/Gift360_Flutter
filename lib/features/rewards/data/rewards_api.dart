import 'package:dio/dio.dart';

/// Rewards/quiz + Instagram-story endpoints (all committed on the backend).
/// Ported from React `api/rewardApi.ts` and `api/storyApi.ts`.
class RewardsApi {
  final Dio _dio;

  RewardsApi(this._dio);

  Future<Map<String, dynamic>> getStatus(
    String clientId, {
    String? publicId,
  }) async {
    final response = await _dio.get(
      '/v1/rewards/status',
      queryParameters: {
        'clientId': clientId,
        if (publicId != null && publicId.isNotEmpty) 'publicId': publicId,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Opens the payment-cancelled quiz offer (backend verifies the order is
  /// still PENDING and belongs to the client). Mirrors React
  /// `registerPaymentCancellation`.
  Future<Map<String, dynamic>> registerPaymentCancellation(
    String clientId,
    String orderNumber,
  ) async {
    final response = await _dio.post(
      '/v1/rewards/payment-cancelled',
      data: {'clientId': clientId, 'orderNumber': orderNumber},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> startFromBanner(String clientId) async {
    final response = await _dio.post(
      '/v1/rewards/start-from-banner',
      data: {'clientId': clientId},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> startSession(
    String clientId,
    String publicId, {
    String language = 'en',
  }) async {
    final response = await _dio.post(
      '/v1/rewards/start',
      data: {'clientId': clientId, 'publicId': publicId, 'language': language},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> answer(
    String clientId,
    String publicId,
    int questionId,
    int selectedIndex,
  ) async {
    final response = await _dio.post(
      '/v1/rewards/answer',
      data: {
        'clientId': clientId,
        'publicId': publicId,
        'questionId': questionId,
        'selectedIndex': selectedIndex,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> complete(
    String clientId,
    String publicId,
  ) async {
    final response = await _dio.post(
      '/v1/rewards/complete',
      data: {'clientId': clientId, 'publicId': publicId},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> submitInstagramStory(
    String clientId,
    String storyUrl,
  ) async {
    final response = await _dio.post(
      '/v1/instagram-story',
      data: {'clientId': clientId, 'storyUrl': storyUrl},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Claims the account's one-time first-login SuperCoin reward.
  Future<Map<String, dynamic>> claimFirstLoginReward({
    required String deviceId,
  }) async {
    final response = await _dio.post(
      '/v1/supercoin/first-login-reward',
      data: {'deviceId': deviceId},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Live SuperCoin rules used to fill FAQ answers (database-backed).
  Future<Map<String, dynamic>?> scFacts() async {
    try {
      final response = await _dio.get('/v1/support/facts/supercoin');
      if (response.data is Map)
        return (response.data as Map).cast<String, dynamic>();
    } catch (_) {}
    return null;
  }
}
