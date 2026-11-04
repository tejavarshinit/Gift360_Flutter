import 'package:dio/dio.dart';

class SuperCoinIdentity {
  final String identifier;
  final String type;

  const SuperCoinIdentity({required this.identifier, required this.type});

  Map<String, dynamic> toJson() => {'identifier': identifier, 'type': type};
}

/// Brand shown in the SuperCoin convert modal, driven by
/// giftvouchers_brands.supercoin_modal_enabled / _order / _pay_mode (V47).
class SuperCoinModalBrand {
  final String brandId;
  final String brandCode;
  final String brandName;

  /// "SC_ONLY" (convert coins) or "CASH_EARN" (pay cash, earn coins).
  final String payMode;

  /// Earn % for CASH_EARN brands (null for SC_ONLY).
  final double? earnPercent;

  const SuperCoinModalBrand({
    required this.brandId,
    required this.brandCode,
    required this.brandName,
    required this.payMode,
    this.earnPercent,
  });

  bool get isCashEarn => payMode.toUpperCase() == 'CASH_EARN';

  factory SuperCoinModalBrand.fromJson(Map<String, dynamic> json) {
    final rawEarn = json['earnPercent'];
    return SuperCoinModalBrand(
      brandId: (json['brandId'] ?? '').toString(),
      brandCode: (json['brandCode'] ?? '').toString(),
      brandName: (json['brandName'] ?? '').toString(),
      payMode: (json['payMode'] ?? 'SC_ONLY').toString().toUpperCase(),
      earnPercent: rawEarn is num
          ? rawEarn.toDouble()
          : double.tryParse(rawEarn?.toString() ?? ''),
    );
  }
}

class SuperCoinApi {
  final Dio _dio;

  SuperCoinApi(this._dio);

  Future<Map<String, dynamic>> searchUser(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/searchUser', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> enrolUser(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/enrolUser', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> fetchBalance(SuperCoinIdentity identity) =>
      _post('/v1/supercoin/balance', {'identity': identity.toJson()});

  Future<Map<String, dynamic>> initHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/initHold', payload);

  Future<Map<String, dynamic>> authorizeHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/authorizeHold', payload);

  Future<Map<String, dynamic>> createHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/hold', payload);

  Future<Map<String, dynamic>> redeemHold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/redeemHold', payload);

  Future<Map<String, dynamic>> unhold(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/unhold', payload);

  Future<Map<String, dynamic>> refund(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/refund', payload);

  Future<Map<String, dynamic>> fetchTransactions(
    Map<String, dynamic> payload,
  ) => _post('/v1/supercoin/transactions', payload);

  Future<Map<String, dynamic>> fetchExpiring(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/expiring', payload);

  Future<Map<String, dynamic>> fetchTransactionStatus(
    String transactionId,
    Map<String, dynamic> payload,
  ) => _post('/v1/supercoin/transaction/$transactionId/status', payload);

  Future<Map<String, dynamic>> burnAndOrder(Map<String, dynamic> payload) =>
      _post('/v1/supercoin/burn-and-order', payload);

  /// SuperCoin rules for a SKU (POST /v1/supercoin/config). The SKU is
  /// optional -- the backend falls back to its configured default and echoes
  /// the resolved value back in `sku`.
  Future<Map<String, dynamic>> fetchConfig({String? sku}) async {
    final response = await _dio.post(
      '/v1/supercoin/config',
      data: {
        if (sku != null && sku.trim().isNotEmpty)
          'sku': sku.trim().toUpperCase(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Store the balance just fetched so the admin dashboard / snapshot reads
  /// see it (POST /v1/clients/supercoin-balance). `balance` may be a number
  /// or the string 'NA' (non-Flipkart users — mirrors React's
  /// storeSuperCoinBalance). Fire-and-forget friendly: errors are swallowed.
  Future<void> syncBalance(String clientId, Object balance) async {
    try {
      await _dio.post(
        '/v1/clients/supercoin-balance',
        data: {'clientId': clientId, 'balance': balance},
      );
    } catch (_) {}
  }

  /// SuperCoins the cart would earn, computed by the backend with the same
  /// rule it uses to credit them (per-brand earn percent, else the global
  /// rate). Returns {coins, percent}.
  Future<Map<String, dynamic>> earnEstimate(
    List<Map<String, dynamic>> items,
    double cashPayable,
  ) async {
    final response = await _dio.post(
      '/v1/supercoin/earn-estimate',
      data: {'items': items, 'cashPayable': cashPayable},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Per-brand SuperCoin share percent (V51): 0 = cash only, 1..99 = that
  /// percent may be paid in SuperCoins, 100 = SuperCoins only. Keyed by brandId.
  Future<Map<String, double>> fetchBrandShares() async {
    final response = await _dio.get('/v1/supercoin/brand-shares');
    final data = response.data;
    final shares = data is Map<String, dynamic> ? data['shares'] : null;
    final out = <String, double>{};
    if (shares is Map) {
      shares.forEach((key, value) {
        final n = value is num ? value.toDouble() : double.tryParse('$value');
        if (n != null && n >= 0) out[key.toString()] = n > 100 ? 100 : n;
      });
    }
    return out;
  }

  /// Brands shown in the convert modal and how each is paid for.
  Future<List<SuperCoinModalBrand>> fetchModalBrands() async {
    final response = await _dio.get('/v1/supercoin/modal-brands');
    final data = response.data;
    final brands = data is Map<String, dynamic> ? data['brands'] : null;
    if (brands is List) {
      return brands
          .whereType<Map>()
          .map((e) => SuperCoinModalBrand.fromJson(e.cast<String, dynamic>()))
          .where((b) => b.brandId.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }
}
