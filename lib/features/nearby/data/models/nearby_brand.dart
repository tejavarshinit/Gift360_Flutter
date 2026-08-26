import 'dart:convert';
import 'package:gift360/config/app_config.dart';

String? _resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConfig.imageBaseUrl;
  if (base.isEmpty) return url;
  return '$base/${url.startsWith('/') ? url.substring(1) : url}';
}

class NearbyBrand {
  final String brandId;
  final String brandCode;
  final String brandName;
  final String category;
  final String brandType;
  final double minPrice;
  final double maxPrice;
  final double nearestDistanceKm;
  final Map<String, dynamic>? images;

  NearbyBrand({
    required this.brandId,
    required this.brandCode,
    required this.brandName,
    required this.category,
    required this.brandType,
    required this.minPrice,
    required this.maxPrice,
    required this.nearestDistanceKm,
    this.images,
  });

  String? get resolvedImageUrl {
    if (images == null) return null;
    final img = images!;

    // Priority: featured → thumbnail → text → raw → base → small → mobile
    final url = img['featured'] ??
        img['thumbnail'] ??
        img['text'] ??
        img['raw'] ??
        img['base'] ??
        img['small'] ??
        img['mobile'];

    if (url is String && url.isNotEmpty) {
      // Handle nested stringified JSON
      if (url.startsWith('{')) {
        try {
          final nested = jsonDecode(url);
          if (nested is Map) {
            final inner = nested['text'] ?? nested['url'] ?? nested['featured'] ?? nested['thumbnail'];
            if (inner is String && inner.isNotEmpty) return _resolveImageUrl(inner);
          }
          if (nested is String) return _resolveImageUrl(nested);
        } catch (_) {}
      }
      return _resolveImageUrl(url);
    }
    return null;
  }

  factory NearbyBrand.fromJson(Map<String, dynamic> json) {
    return NearbyBrand(
      brandId: json['brand_id'] ?? json['brandId'] ?? '',
      brandCode: json['brand_code'] ?? json['brandCode'] ?? '',
      brandName: json['brand_name'] ?? json['brandName'] ?? '',
      category: json['category'] ?? '',
      brandType: json['brand_type'] ?? json['brandType'] ?? '',
      minPrice: (json['min_price'] ?? json['minPrice'] ?? 0).toDouble(),
      maxPrice: (json['max_price'] ?? json['maxPrice'] ?? 0).toDouble(),
      nearestDistanceKm: (json['nearest_distance_km'] ?? json['nearestDistanceKm'] ?? 0).toDouble(),
      images: _parseImages(json['images']),
    );
  }

  static Map<String, dynamic>? _parseImages(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map<String, dynamic>) return raw;

    if (raw is String && raw.isNotEmpty) {
      // If starts with http, treat as direct URL
      if (raw.startsWith('http')) {
        return {'featured': raw, 'thumbnail': raw, 'text': raw};
      }
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
        if (parsed is String && parsed.startsWith('http')) {
          return {'featured': parsed, 'thumbnail': parsed, 'text': parsed};
        }
      } catch (_) {}
    }
    return null;
  }
}

class NearbyBrandsResponse {
  final String category;
  final Map<String, String> center;
  final String radiusKm;
  final List<NearbyBrand> brands;

  NearbyBrandsResponse({
    required this.category,
    required this.center,
    required this.radiusKm,
    required this.brands,
  });

  factory NearbyBrandsResponse.fromJson(Map<String, dynamic> json) {
    return NearbyBrandsResponse(
      category: json['category'] ?? '',
      center: Map<String, String>.from(json['center'] ?? {}),
      radiusKm: json['radius_km'] ?? json['radiusKm'] ?? '',
      brands: (json['brands'] as List<dynamic>?)
              ?.map((b) => NearbyBrand.fromJson(b))
              .toList() ??
          [],
    );
  }
}
