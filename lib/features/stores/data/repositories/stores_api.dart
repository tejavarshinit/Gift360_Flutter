import 'package:dio/dio.dart';

class StoresApi {
  final Dio _dio;

  StoresApi(this._dio);

  Future<List<Map<String, dynamic>>> getStores(String brandId) async {
    final response = await _dio.post('/stores/get/$brandId');
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<Map<String, dynamic>> getNearbyStores(Map<String, dynamic> request) async {
    final response = await _dio.post('/v1/stores/nearby', data: request);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNearbyBrands(Map<String, dynamic> request) async {
    final response = await _dio.post('/v1/stores/nearby/brands', data: request);
    return response.data as Map<String, dynamic>;
  }
}
