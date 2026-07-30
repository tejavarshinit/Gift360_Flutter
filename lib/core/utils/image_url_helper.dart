import 'dart:convert';

String? resolveBrandImageUrl(dynamic imageData, {String? fallbackUrl}) {
  if (imageData == null) return fallbackUrl;

  if (imageData is Map<String, dynamic>) {
    return imageData['featured'] ??
        imageData['thumbnail'] ??
        imageData['mobile'] ??
        imageData['raw'] ??
        imageData['base'] ??
        imageData['small'] ??
        imageData['text'] ??
        fallbackUrl;
  }

  if (imageData is String && imageData.isNotEmpty) {
    if (imageData.startsWith('{')) {
      try {
        final decoded = jsonDecode(imageData);
        if (decoded is Map<String, dynamic>) {
          return decoded['featured'] ??
              decoded['thumbnail'] ??
              decoded['mobile'] ??
              decoded['raw'] ??
              decoded['base'] ??
              decoded['small'] ??
              decoded['text'] ??
              fallbackUrl;
        }
      } catch (_) {}
    }
    return imageData;
  }

  return fallbackUrl;
}
