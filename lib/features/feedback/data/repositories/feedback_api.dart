import 'package:dio/dio.dart';

class FeedbackApi {
  final Dio _dio;

  FeedbackApi(this._dio);

  Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> data) async {
    final response = await _dio.post('/v1/feedback', data: data);
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Backend-side "has this customer ever submitted feedback" check.
  /// Mirrors React `getFeedbackStatus` (`GET /v1/feedback/status`).
  Future<Map<String, dynamic>> getStatus(String clientId) async {
    final response = await _dio.get(
      '/v1/feedback/status',
      queryParameters: {'clientId': clientId},
    );
    return (response.data as Map).cast<String, dynamic>();
  }
}
