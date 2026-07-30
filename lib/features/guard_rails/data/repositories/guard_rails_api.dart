import 'package:dio/dio.dart';

class GuardRailsApi {
  final Dio _dio;

  GuardRailsApi(this._dio);

  Future<List<Map<String, dynamic>>> getBrands() async {
    final response = await _dio.post('/guard-rails/brands');
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<dynamic> getClientUsage(Map<String, dynamic> payload) async {
    final response = await _dio.post('/guard-rails/client-usage', data: payload);
    return response.data;
  }
}
