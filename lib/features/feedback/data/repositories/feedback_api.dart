import 'package:dio/dio.dart';

class FeedbackApi {
  final Dio _dio;

  FeedbackApi(this._dio);

  Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> data) async {
    final response = await _dio.post('/v1/feedback', data: data);
    return response.data as Map<String, dynamic>;
  }
}
