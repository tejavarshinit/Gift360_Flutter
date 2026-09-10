import 'dart:convert';

String? _normalizeImageValue(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['featured', 'thumbnail', 'mobile', 'raw', 'base', 'small', 'text']) {
          final nested = _normalizeImageValue(decoded[key]);
          if (nested != null && nested.isNotEmpty) {
            return nested;
          }
        }
      } else if (decoded is String) {
        return _normalizeImageValue(decoded);
      }
    } catch (_) {}

    return trimmed;
  }

  if (value is Map) {
    for (final key in const ['featured', 'thumbnail', 'mobile', 'raw', 'base', 'small', 'text']) {
      final nested = _normalizeImageValue(value[key]);
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
  }

  return value.toString();
}

class Brand {
  final String? brandId;
  final String? brandName;
  final String? category;
  final String? discount;
  final double? minPrice;
  final double? maxPrice;
  final String? description;
  final String? imageUrl;
  final String? logoUrl;
  final String? brandImageUrl;
  final String? terms;
  final String? validity;
  final String? denomination;
  final String? howToUse;
  final String? brandCode;
  final BrandImages? images;
  final String? brandType;
  final String? denominationList;
  final String? importantInstruction;
  final double? supercoinMultiplier;

  const Brand({
    this.brandId,
    this.brandName,
    this.category,
    this.discount,
    this.minPrice,
    this.maxPrice,
    this.description,
    this.imageUrl,
    this.logoUrl,
    this.brandImageUrl,
    this.terms,
    this.validity,
    this.denomination,
    this.howToUse,
    this.brandCode,
    this.images,
    this.brandType,
    this.denominationList,
    this.importantInstruction,
    this.supercoinMultiplier,
  });

  Brand copyWith({
    String? brandId,
    String? brandName,
    String? category,
    String? discount,
    double? minPrice,
    double? maxPrice,
    String? description,
    String? imageUrl,
    String? logoUrl,
    String? brandImageUrl,
    String? terms,
    String? validity,
    String? denomination,
    String? howToUse,
    String? brandCode,
    BrandImages? images,
    String? brandType,
    String? denominationList,
    String? importantInstruction,
    double? supercoinMultiplier,
  }) {
    return Brand(
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      category: category ?? this.category,
      discount: discount ?? this.discount,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      brandImageUrl: brandImageUrl ?? this.brandImageUrl,
      terms: terms ?? this.terms,
      validity: validity ?? this.validity,
      denomination: denomination ?? this.denomination,
      howToUse: howToUse ?? this.howToUse,
      brandCode: brandCode ?? this.brandCode,
      images: images ?? this.images,
      brandType: brandType ?? this.brandType,
      denominationList: denominationList ?? this.denominationList,
      importantInstruction: importantInstruction ?? this.importantInstruction,
      supercoinMultiplier: supercoinMultiplier ?? this.supercoinMultiplier,
    );
  }

  String? get resolvedImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    if (images != null) {
      return _normalizeImageValue(images!.featured) ??
          _normalizeImageValue(images!.thumbnail) ??
          _normalizeImageValue(images!.mobile) ??
          _normalizeImageValue(images!.raw) ??
          _normalizeImageValue(images!.base) ??
          _normalizeImageValue(images!.small) ??
          _normalizeImageValue(images!.text);
    }
    return null;
  }

  /// When minPrice/maxPrice are both 0 (unset), fall back to the first
  /// value in denominationList so the UI always shows a meaningful price.
  double get effectiveStartingPrice {
    final min = minPrice ?? 0;
    final max = maxPrice ?? 0;
    if (min > 0) return min;
    if (max > 0) return max;
    final denomSource = denominationList ?? denomination;
    if (denomSource != null && denomSource.isNotEmpty) {
      final values = denomSource
          .split(',')
          .map((e) => double.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList();
      if (values.isNotEmpty) return values.first;
    }
    return 0;
  }

  factory Brand.fromJson(Map<String, dynamic> json) {
    final imageData = json['image'] ?? json['images'] ?? json['brand_image_url'] ?? json['brandImageUrl'];
    BrandImages? parsedImages;
    if (imageData is Map<String, dynamic>) {
      parsedImages = BrandImages.fromJson(imageData);
    } else if (imageData is String && imageData.isNotEmpty) {
      try {
        final decoded = jsonDecode(imageData);
        if (decoded is Map<String, dynamic>) {
          parsedImages = BrandImages.fromJson(decoded);
        } else {
          parsedImages = BrandImages(raw: imageData, featured: imageData, thumbnail: imageData);
        }
      } catch (_) {
        parsedImages = BrandImages(raw: imageData, featured: imageData, thumbnail: imageData);
      }
    }

    return Brand(
      brandId: json['BrandId'] as String? ?? json['brandId'] as String? ?? json['id'] as String? ?? json['brand_id'] as String? ?? json['BrandCode'] as String? ?? json['brandCode'] as String?,
      brandName: json['BrandName'] as String? ?? json['brandName'] as String? ?? json['brand_name'] as String?,
      category: json['Category'] as String? ?? json['category'] as String?,
      discount: (json['Discount'] ?? json['discount'] ?? json['cashback'])?.toString(),
      minPrice: (json['MinPrice'] ?? json['minPrice'])?.toDouble(),
      maxPrice: (json['MaxPrice'] ?? json['maxPrice'])?.toDouble(),
      description: json['Description'] as String? ?? json['description'] as String?,
      imageUrl: _extractImageUrl(json),
      logoUrl: json['LogoURL'] as String? ?? json['logoUrl'] as String?,
      brandImageUrl: json['BrandImageURL'] as String? ?? json['brandImageUrl'] as String? ?? json['brand_image_url'] as String?,
      terms: json['Terms'] as String? ?? json['terms'] as String? ?? _parseJsonTextField(json['tnc']),
      validity: json['Validity'] as String? ?? json['validity'] as String?,
      denomination: json['Denomination'] as String? ?? json['denomination'] as String?,
      howToUse: json['HowToUse'] as String? ?? json['howToUse'] as String? ?? _parseJsonTextField(json['redeemSteps']),
      importantInstruction: _parseJsonTextField(json['importantInstruction']) ?? _parseJsonTextField(json['important_instruction']),
      brandCode: json['BrandCode'] as String? ?? json['brandCode'] as String?,
      images: parsedImages,
      brandType: json['brandType'] as String? ?? json['BrandType'] as String? ?? json['brand_type'] as String?,
      denominationList: json['denominationList'] as String? ?? json['DenominationList'] as String? ?? json['denomination_list'] as String?,
      supercoinMultiplier: _parseDouble(json['supercoinMultiplier']),
    );
  }

  static String? _extractImageUrl(Map<String, dynamic> json) {
    final imageData = json['image'];
    if (imageData is Map<String, dynamic>) {
      return _normalizeImageValue(imageData['featured']) ??
          _normalizeImageValue(imageData['thumbnail']) ??
          _normalizeImageValue(imageData['mobile']) ??
          _normalizeImageValue(imageData['raw']) ??
          _normalizeImageValue(imageData['base']) ??
          _normalizeImageValue(imageData['small']);
    }
    if (imageData is String && imageData.isNotEmpty) {
      return _normalizeImageValue(imageData);
    }
    final directBrandImage = _normalizeImageValue(json['brand_image_url']);
    if (directBrandImage != null) return directBrandImage;
    final camelBrandImage = _normalizeImageValue(json['brandImageUrl']);
    if (camelBrandImage != null) return camelBrandImage;
    // fetchbrands/occasions API returns imageUrl (camelCase) as a direct URL string
    final imageUrl = _normalizeImageValue(json['imageUrl']);
    if (imageUrl != null) return imageUrl;
    final ImageUrl = _normalizeImageValue(json['ImageUrl']);
    if (ImageUrl != null) return ImageUrl;
    return null;
  }

  /// Parses a JSON-encoded text field like `{"text":"..."}` or a plain string.
  /// Returns the extracted text, or null if empty/parse fails.
  static String? _parseJsonTextField(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.isEmpty) return null;
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded['text'] as String? ?? decoded.values.firstOrNull?.toString();
        }
        if (decoded is String) return decoded;
      } catch (_) {}
      return value;
    }
    if (value is Map<String, dynamic>) {
      return value['text'] as String? ?? value.values.firstOrNull?.toString();
    }
    return value.toString();
  }

  /// Safely parse a value to double, handling String, num, and null.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class BrandImages {
  final String? raw;
  final String? featured;
  final String? thumbnail;
  final String? mobile;
  final String? base;
  final String? small;
  final String? text;

  const BrandImages({
    this.raw,
    this.featured,
    this.thumbnail,
    this.mobile,
    this.base,
    this.small,
    this.text,
  });

  factory BrandImages.fromJson(Map<String, dynamic> json) {
    return BrandImages(
      raw: _normalizeImageValue(json['raw']),
      featured: _normalizeImageValue(json['featured']),
      thumbnail: _normalizeImageValue(json['thumbnail']),
      mobile: _normalizeImageValue(json['mobile']),
      base: _normalizeImageValue(json['base']),
      small: _normalizeImageValue(json['small']),
      text: _normalizeImageValue(json['text']),
    );
  }
}

class BrandVoucher {
  final String brandId;
  final String brandName;
  final String? description;
  final double? minPrice;
  final double? maxPrice;
  final String? discount;
  final String? imageUrl;
  final String? terms;
  final String? validity;
  final String? denomination;
  final String? howToUse;

  const BrandVoucher({
    required this.brandId,
    required this.brandName,
    this.description,
    this.minPrice,
    this.maxPrice,
    this.discount,
    this.imageUrl,
    this.terms,
    this.validity,
    this.denomination,
    this.howToUse,
  });

  factory BrandVoucher.fromJson(Map<String, dynamic> json) {
    return BrandVoucher(
      brandId: json['brandId'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      description: json['description'] as String?,
      minPrice: (json['minPrice'])?.toDouble(),
      maxPrice: (json['maxPrice'])?.toDouble(),
      discount: json['discount'] as String?,
      imageUrl: json['imageUrl'] as String?,
      terms: json['terms'] as String?,
      validity: json['validity'] as String?,
      denomination: json['denomination'] as String?,
      howToUse: json['howToUse'] as String?,
    );
  }
}
