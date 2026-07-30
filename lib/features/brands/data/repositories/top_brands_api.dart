import 'package:dio/dio.dart';
import 'package:gift360/features/brands/data/models/brand.dart';

class TopBrandsApi {
  final Dio _dio;

  TopBrandsApi(this._dio);

  Future<List<Brand>> fetchTopBrands() async {
    final response = await _dio.post('/v1/fetchbrands', data: {});
    final data = response.data;
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      items = data['data'] ?? data['brands'] ?? data['result'] ?? [];
    } else {
      items = [];
    }
    return items
        .map((e) => Brand.fromJson(e as Map<String, dynamic>))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }
}
