class AnalyticsService {
  static Future<void> trackPageView(String path, {String? title}) async {
    // GA4 gtag.js equivalent - web only
    // On mobile, use firebase_analytics if available
    assert(() {
      print('[Analytics] page_view: $path');
      return true;
    }());
  }

  static Future<void> trackEvent(String eventName, {Map<String, dynamic>? params}) async {
    assert(() {
      print('[Analytics] event: $eventName, params: $params');
      return true;
    }());
  }

  static Future<void> trackAddToCart({
    required String brandId,
    required int quantity,
    required double price,
  }) async {
    await trackEvent('add_to_cart', params: {
      'items': [
        {
          'item_id': brandId,
          'quantity': quantity,
          'price': price,
        }
      ],
      'value': quantity * price,
      'currency': 'INR',
    });
  }

  static Future<void> trackPurchase({
    required String orderId,
    required double value,
    required List<Map<String, dynamic>> items,
  }) async {
    await trackEvent('purchase', params: {
      'transaction_id': orderId,
      'value': value,
      'currency': 'INR',
      'items': items,
    });
  }

  static Future<void> trackViewItem({
    required String brandId,
    required String brandName,
    String? category,
    double? price,
  }) async {
    await trackEvent('view_item', params: {
      'items': [
        {
          'item_id': brandId,
          'item_name': brandName,
          'item_category': category,
          'price': price,
        }
      ],
    });
  }

  static Future<void> trackSuperCoinUsed({required double amount}) async {
    await trackEvent('supercoin_used', params: {'value': amount});
  }

  static Future<void> trackSuperCoinRemoved({required double amount}) async {
    await trackEvent('supercoin_removed', params: {'value': amount});
  }
}
