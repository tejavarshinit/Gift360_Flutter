import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Reseller-side models + local persistence (session, cart, buyer, idempotency).
/// Ported from React `api/resellerApi.ts`.
const String _sessionKey = 'resellerSession';
const String _cartKey = 'resellerCart';
const String _buyerKey = 'resellerBuyer';
const String _idemKey = 'resellerOrderIdem';
const int maxResellerQuantityPerSku = 3;

class ResellerSession {
  final String token;
  final String resellerId;
  final int savedAt;

  const ResellerSession({
    required this.token,
    required this.resellerId,
    required this.savedAt,
  });

  factory ResellerSession.fromJson(Map<String, dynamic> json) =>
      ResellerSession(
        token: (json['token'] ?? '').toString(),
        resellerId: (json['resellerId'] ?? '').toString(),
        savedAt: (json['savedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'token': token,
    'resellerId': resellerId,
    'savedAt': savedAt,
  };
}

class ResellerCartItem {
  final String brandSku;
  final String brandName;
  final String? image;
  final double unitPrice;
  int quantity;

  /// Reseller discount percent for this SKU (0 = none).
  final double discount;

  ResellerCartItem({
    required this.brandSku,
    required this.brandName,
    this.image,
    required this.unitPrice,
    required this.quantity,
    this.discount = 0,
  });

  double get lineTotal => unitPrice * quantity * (1 - discount / 100);

  factory ResellerCartItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    return ResellerCartItem(
      brandSku: (json['brandSku'] ?? '').toString(),
      brandName: (json['brandName'] ?? '').toString(),
      image: json['image']?.toString(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      quantity: quantity.clamp(1, maxResellerQuantityPerSku).toInt(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'brandSku': brandSku,
    'brandName': brandName,
    if (image != null) 'image': image,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'discount': discount,
  };
}

class ResellerBuyer {
  final String fullName;
  final String email;
  final String mobile;

  const ResellerBuyer({
    required this.fullName,
    required this.email,
    required this.mobile,
  });

  factory ResellerBuyer.fromJson(Map<String, dynamic> json) => ResellerBuyer(
    fullName: (json['fullName'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    mobile: (json['mobile'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'mobile': mobile,
  };
}

class ResellerStore {
  ResellerStore._();

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<ResellerSession?> getSession() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ResellerSession.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSession(ResellerSession session) async {
    final prefs = await _prefs();
    try {
      await prefs?.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    final prefs = await _prefs();
    try {
      await prefs?.remove(_sessionKey);
    } catch (_) {}
  }

  static Future<List<ResellerCartItem>> getCart() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_cartKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => ResellerCartItem.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCart(List<ResellerCartItem> items) async {
    final prefs = await _prefs();
    try {
      await prefs?.setString(
        _cartKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {}
  }

  static Future<void> clearCart() async {
    final prefs = await _prefs();
    try {
      await prefs?.remove(_cartKey);
    } catch (_) {}
  }

  static Future<ResellerBuyer?> getBuyer() async {
    final prefs = await _prefs();
    final raw = prefs?.getString(_buyerKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ResellerBuyer.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBuyer(ResellerBuyer buyer) async {
    final prefs = await _prefs();
    try {
      await prefs?.setString(_buyerKey, jsonEncode(buyer.toJson()));
    } catch (_) {}
  }

  /// Same cart + buyer => same key on retry (server replays, no double debit);
  /// any change to the checkout makes it a fresh order/key.
  static Future<String> getOrderIdempotencyKey(String signature) async {
    final prefs = await _prefs();
    try {
      final raw = prefs?.getString(_idemKey);
      if (raw != null && raw.isNotEmpty) {
        final v = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final sig = v['sig']?.toString();
        final key = v['key']?.toString();
        if (sig == signature &&
            key != null &&
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
            ).hasMatch(key)) {
          return key;
        }
      }
    } catch (_) {}

    // React uses crypto.randomUUID() for the idempotency key. Keep the same
    // UUID v4 format so backend validation/replay behavior matches exactly.
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final key =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    try {
      await prefs?.setString(
        _idemKey,
        jsonEncode({'sig': signature, 'key': key}),
      );
    } catch (_) {}
    return key;
  }

  static Future<void> clearOrderIdempotencyKey() async {
    final prefs = await _prefs();
    try {
      await prefs?.remove(_idemKey);
    } catch (_) {}
  }
}

/// RFC-4180 style CSV export of flattened voucher (credential) rows.
String resellerVouchersToCsv(List<Map<String, dynamic>> rows) {
  String esc(Object? v) {
    final s = v == null ? '' : v.toString();
    return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  const header = [
    'Order Number',
    'Client Reference',
    'Order Date',
    'Brand SKU',
    'Brand Name',
    'Card Number',
    'Card PIN',
    'Activation Code',
    'Activation URL',
    'Expiry',
  ];
  final lines = rows.map(
    (r) => [
      r['orderNumber'],
      r['clientOrderRef'],
      r['orderDate'],
      r['brandSku'],
      r['brandName'],
      r['cardNumber'],
      r['cardPin'],
      r['activationCode'],
      r['activationUrl'],
      r['expiry'],
    ].map(esc).join(','),
  );
  return [header.join(','), ...lines].join('\r\n');
}
