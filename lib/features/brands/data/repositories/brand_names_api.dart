import 'package:dio/dio.dart';
import 'package:gift360/features/brands/data/models/brand_name.dart';

class BrandNamesApi {
  final Dio _dio;

  BrandNamesApi(this._dio);

  Future<List<BrandName>> getBrandNames() async {
    final response = await _dio.post('/brands/getallnames', data: {});
    final data = response.data;
    if (data is List) {
      return data.map((e) => BrandName.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
