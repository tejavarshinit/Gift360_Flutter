import 'package:dio/dio.dart';
import 'package:gift360/features/brands/data/models/brand.dart';

class BrandsApi {
  final Dio _dio;

  BrandsApi(this._dio);

  List<Map<String, dynamic>> _extractItems(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }

    if (data is Map<String, dynamic>) {
      final items = data['data'] ?? data['brands'] ?? data['result'] ?? data['items'];
      if (items is List) {
        return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      if (items is Map<String, dynamic>) {
        return [items];
      }
      return [data];
    }

    return const [];
  }

  Future<List<Brand>> getBrands() async {
    final response = await _dio.post('/v1/fetchbrands', data: {});
    final items = _extractItems(response.data);
    return items
        .map((e) => Brand.fromJson(e))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  Future<Brand> getBrandDetails(String brandId) async {
    final response = await _dio.post('/v1/fetchbranddetails', data: {'brand_id': brandId});
    final items = _extractItems(response.data);
    if (items.isEmpty) {
      throw Exception('Brand details not found');
    }
    final brands = items.map((e) {
      final brand = Brand.fromJson(e);
      if (brand.brandId == null || brand.brandId!.isEmpty) {
        return brand.copyWith(brandId: brandId);
      }
      return brand;
    }).toList();
    return brands.firstWhere(
      (b) => b.brandId == brandId,
      orElse: () => brands.first,
    );
  }

  Future<List<Brand>> getBrandVoucherList(String brandId) async {
    final response = await _dio.post('/v1/fetchbranddetails', data: {'brand_id': brandId});
    final items = _extractItems(response.data);
    return items
        .map((e) {
          final brand = Brand.fromJson(e);
          // Inject the original brandId if parsing couldn't extract one
          // (matches React fallback: item.brandId || item.brand_id || brandId)
          if (brand.brandId == null || brand.brandId!.isEmpty) {
            return brand.copyWith(brandId: brandId);
          }
          return brand;
        })
        .where((b) => b.brandName != null && b.brandName!.isNotEmpty)
        .toList();
  }

  Future<List<Brand>> searchBrands(String query) async {
    final response = await _dio.post('/brands/search', data: {'searchText': query});
    final data = response.data;
    if (data is List) {
      return data.map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<Brand>> getTopBrands({String? occasion}) async {
    final response = await _dio.post('/v1/fetchbrands', data: occasion != null ? {'occasion': occasion} : {});
    final items = _extractItems(response.data);
    return items
        .map(Brand.fromJson)
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  Future<Map<String, dynamic>> getFilterMeta() async {
    final response = await _dio.post('/brands/filter-meta', data: {});
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> getAllBrands() async {
    final response = await _dio.post('/v1/fetchbrands', data: {});
    return _extractItems(response.data);
  }

  Future<List<Brand>> getBrandsWithCategory() async {
    final response = await _dio.post('/brands/getall', data: {});
    final items = _extractItems(response.data);
    return items
        .map((e) => Brand.fromJson(e))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  Future<Brand> getBrandById(String brandId) async {
    final response = await _dio.post('/brands/$brandId', data: {});
    final items = _extractItems(response.data);
    if (items.isNotEmpty) {
      final brand = Brand.fromJson(items.first);
      if (brand.brandId == null || brand.brandId!.isEmpty) {
        return brand.copyWith(brandId: brandId);
      }
      return brand;
    }
    if (response.data is Map<String, dynamic>) {
      final brand = Brand.fromJson(response.data as Map<String, dynamic>);
      if (brand.brandId == null || brand.brandId!.isEmpty) {
        return brand.copyWith(brandId: brandId);
      }
      return brand;
    }
    throw Exception('Brand payment details not found');
  }

  /// Fetch brand details via POST /brands/{brandId} (matches React's useBrandDetails).
  /// This endpoint returns supercoinMultiplier and other brand-specific data.
  Future<Brand> getBrandDetailsById(String brandId) async {
    final response = await _dio.post('/brands/$brandId', data: {});
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return Brand.fromJson(data);
    }
    throw Exception('Brand details not found');
  }

  Future<List<Map<String, dynamic>>> filterBrands(Map<String, dynamic> filter) async {
    final response = await _dio.post('/brands/filter', data: filter);
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) {
      final items = data['data'] ?? data['brands'] ?? data['result'] ?? [];
      if (items is List) return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchNewOrders(String clientId, {int timeline = 12, String? type}) async {
    final response = await _dio.post('/v1/neworders', data: {
      'clientId': clientId,
      'timeline': timeline,
      if (type != null) 'type': type,
    });
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    if (data is Map) {
      final items = data['data'] ?? data['orders'] ?? data['result'] ?? [];
      if (items is List) return items.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Brand>> getFilteredBrandsList(Map<String, dynamic> filter) async {
    final rawItems = await filterBrands(filter);
    return rawItems
        .map((e) => Brand.fromJson(e))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  Future<List<Brand>> getFilteredBrands({
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minDiscount,
    String? sortBy,
  }) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    if (minPrice != null) params['minPrice'] = minPrice;
    if (maxPrice != null) params['maxPrice'] = maxPrice;
    if (minDiscount != null) params['minDiscount'] = minDiscount;
    if (sortBy != null) params['sortBy'] = sortBy;

    final response = await _dio.post('/brands/getall', data: params);
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

  /// Fetch available occasion categories for recommendations.
  Future<List<String>> getOccasions() async {
    final response = await _dio.post('/v1/occasions', data: {});
    final data = response.data;
    if (data is List) {
      return data.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  /// Fetch occasion-based brands using the same fetchbrands payload as React.
  Future<List<Brand>> getRecommendations(String occasion) async {
    final response = await _dio.post('/v1/fetchbrands', data: {'occasion': occasion});
    final items = _extractItems(response.data);
    return items
        .map((e) => Brand.fromJson(e))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  /// Fetch personalized brand recommendations for the user.
  Future<List<Brand>> getPersonalRecommendations() async {
    final response = await _dio.post('/v1/personal-recommendations', data: {});
    final items = _extractItems(response.data);
    return items
        .map((e) => Brand.fromJson(e))
        .where((b) => b.brandId != null && b.brandName != null)
        .toList();
  }

  /// Fetch live platform fee configuration (feePercent, feeMax).
  Future<Map<String, dynamic>> getPlatformFeeConfig() async {
    final response = await _dio.get('/v1/platform-fee-config');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'feePercent': 0.02, 'feeMax': 20.0};
  }
}
