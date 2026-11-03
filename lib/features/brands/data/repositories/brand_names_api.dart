import 'package:dio/dio.dart';
import 'package:gift360/features/brands/data/models/brand_name.dart';
import 'package:gift360/features/supercoin/data/hidden_catalog_brands.dart';

class BrandNamesApi {
  final Dio _dio;

  BrandNamesApi(this._dio);

  Future<List<BrandName>> getBrandNames() async {
    final response = await _dio.post('/brands/getallnames', data: {});
    final data = response.data;
    if (data is List) {
      return data
          .map((e) => BrandName.fromJson(e as Map<String, dynamic>))
          .where((b) => !isHiddenCatalogBrand(b.brandId, b.brandName))
          .toList();
    }
    return [];
  }
}
