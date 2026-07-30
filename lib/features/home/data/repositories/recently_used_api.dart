import 'dart:convert';

import 'package:dio/dio.dart';

class RecentlyUsedBrand {
  final String brandId;
  final String brandName;
  final String? imageUrl;

  const RecentlyUsedBrand({
    required this.brandId,
    required this.brandName,
    this.imageUrl,
  });

  factory RecentlyUsedBrand.fromOrder(Map<String, dynamic> json) {
    final items = json['items'];
    Map<String, dynamic> firstItem = const {};
    if (items is List && items.isNotEmpty && items.first is Map) {
      firstItem = Map<String, dynamic>.from(items.first as Map);
    }
    final meta = firstItem['meta'];
    Map<String, dynamic> metaMap = const {};
    if (meta is Map) {
      metaMap = Map<String, dynamic>.from(meta as Map);
    }

    final brandId = _stringValue(metaMap, ['brandId', 'brand_id']) ??
        _stringValue(firstItem, ['brandId', 'brand_id']) ??
        _stringValue(json, ['brandId', 'brand_id']) ??
        '';
    final brandName = _stringValue(metaMap, ['brand_name', 'brandName']) ??
        _stringValue(firstItem, ['brand_name', 'brandName']) ??
        _stringValue(json, ['brand_name', 'brandName']) ??
        'Voucher';

    return RecentlyUsedBrand(
      brandId: brandId,
      brandName: brandName,
      imageUrl: _getImageUrl(metaMap) ?? _getImageUrl(firstItem) ?? _cdnFallback(brandId),
    );
  }

  static String? _stringValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _getImageUrl(Map<String, dynamic> item) {
    if (item.isEmpty) return null;

    // Priority 1: Direct ImageUrl
    final imageUrl = item['ImageUrl'];
    if (imageUrl is String && imageUrl.isNotEmpty) return imageUrl;

    // Priority 2: brand_image_url (direct string)
    final brandImageUrl = item['brand_image_url'];
    if (brandImageUrl is String && brandImageUrl.isNotEmpty) return brandImageUrl;

    // Priority 3: image.raw (may be stringified JSON)
    final rawUrl = _parseStringifiedJsonField(item['image'], 'raw');
    if (rawUrl != null) return rawUrl;

    // Priority 4: Images (PascalCase) object
    final imagesObj = item['Images'];
    if (imagesObj is Map<String, dynamic>) {
      final url = _pickFromImageMap(imagesObj);
      if (url != null) return url;
    }

    // Priority 5: image field (may be object or string)
    final imageField = item['image'];
    if (imageField is Map<String, dynamic>) {
      final url = _pickFromImageMap(imageField);
      if (url != null) return url;
    }
    if (imageField is String && imageField.isNotEmpty) {
      return _parseStringOrJson(imageField);
    }

    // Priority 6: Legacy Image / images fields
    for (final key in ['Image', 'images']) {
      final val = item[key];
      if (val is String && val.isNotEmpty) {
        final parsed = _parseStringOrJson(val);
        if (parsed != null) return parsed;
      }
      if (val is Map<String, dynamic>) {
        final url = _pickFromImageMap(val);
        if (url != null) return url;
      }
    }

    // Priority 7: Other direct string fields
    final directUrl = _stringValue(item, [
      'imageUrl',
      'brandImageUrl',
      'image_url',
      'brand_image',
    ]);
    if (directUrl != null) return directUrl;

    return null;
  }

  static String? _pickFromImageMap(Map<String, dynamic> map) {
    for (final key in ['featured', 'thumbnail', 'mobile', 'raw', 'base', 'small', 'text']) {
      final value = map[key];
      if (value is String && value.isNotEmpty) {
        return _parseStringOrJson(value);
      }
    }
    return null;
  }

  static String? _parseStringifiedJsonField(dynamic imageField, String subKey) {
    if (imageField is Map<String, dynamic>) {
      final value = imageField[subKey];
      if (value is String && value.isNotEmpty) {
        return _parseStringOrJson(value);
      }
    }
    return null;
  }

  static String? _parseStringOrJson(String value) {
    if (value.isEmpty) return null;
    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded['text'] ??
              decoded['featured'] ??
              decoded['thumbnail'] ??
              decoded['mobile'] ??
              decoded['raw'] ??
              decoded['base'] ??
              decoded['small'] ??
              value;
        }
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return value;
  }

  static String? _cdnFallback(String brandId) {
    if (brandId.isEmpty) return null;
    return 'https://images.gift360.io/$brandId.png';
  }
}

class RecentlyUsedApi {
  final Dio _dio;

  RecentlyUsedApi(this._dio);

  Future<List<RecentlyUsedBrand>> fetchRecentlyUsed({
    required String clientId,
    int timeline = 12,
  }) async {
    final response = await _dio.post('/v1/neworders', data: {
      'clientId': clientId,
      'timeline': timeline,
    });

    final data = response.data;
    final orders = <Map<String, dynamic>>[];
    if (data is Map<String, dynamic>) {
      final rawOrders = data['orders'] ?? data['data'] ?? data['result'];
      if (rawOrders is List) {
        orders.addAll(rawOrders.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      }
    } else if (data is List) {
      orders.addAll(data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    }

    final paidOrders = orders
        .where((order) => (order['status']?.toString().toUpperCase() ?? '') == 'PAID')
        .toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a['created_at']?.toString() ?? a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = DateTime.tryParse(b['created_at']?.toString() ?? b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    final seen = <String>{};
    final result = <RecentlyUsedBrand>[];
    for (final order in paidOrders) {
      final item = RecentlyUsedBrand.fromOrder(order);
      final key = item.brandName.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(item);
      if (result.length >= 6) break;
    }

    return result;
  }
}
