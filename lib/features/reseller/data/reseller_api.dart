import 'package:dio/dio.dart';

/// Reseller API client, ported from React `api/resellerApi.ts`.
///
/// Reseller auth is a separate single-session JWT (NOT the consumer token):
///   POST /v1/reseller/auth/login           email + password -> JWT
///   POST /v1/reseller/auth/jwt             (Bearer) -> clientId + clientSecretHash
///   every BUSINESS POST                    carries those two in the JSON body,
///                                          fetched immediately before the call
///                                          (never persisted client-side)
class ResellerApi {
  final Dio _dio;
  final String? Function() _token;

  ResellerApi(this._dio, this._token);

  static String _message(Object? data, String fallback) {
    if (data is String && data.trim().isNotEmpty) return data;
    if (data is Map) {
      final m = data['message'] ?? data['error'];
      if (m != null && m.toString().trim().isNotEmpty) return m.toString();
    }
    return fallback;
  }

  static String errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) return 'Session expired. Please login again.';
      return _message(error.response?.data, fallback);
    }
    return fallback;
  }

  static int? statusOf(Object error) =>
      error is DioException ? error.response?.statusCode : null;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post(
      '/v1/reseller/auth/login',
      data: {'email': email, 'password': password},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await _dio.post(
      '/v1/reseller/auth/forgot-password',
      data: {'email': email},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> resetPassword(
    String token,
    String password,
  ) async {
    final res = await _dio.post(
      '/v1/reseller/auth/reset-password',
      data: {'token': token, 'password': password},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Options get _bearer =>
      Options(headers: {'Authorization': 'Bearer ${_token() ?? ''}'});

  /// Best-effort: clears the single-session JWT server-side.
  Future<void> logout() async {
    try {
      await _dio.post('/v1/reseller/auth/logout', data: {}, options: _bearer);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> fetchJwt() async {
    final res = await _dio.post(
      '/v1/reseller/auth/jwt',
      data: {},
      options: _bearer,
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Fetch fresh credentials and attach them to a JSON request body.
  Future<Map<String, dynamic>> _withCredentials(
    Map<String, dynamic> payload,
  ) async {
    final creds = await fetchJwt();
    return {
      ...payload,
      'clientId': creds['clientId'],
      'clientSecretHash': creds['clientSecretHash'],
    };
  }

  Future<double> fetchWallet() async {
    final res = await _dio.post(
      '/v1/reseller/wallet/balance',
      data: await _withCredentials({}),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    return (data['walletBalance'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchWalletTransactions() async {
    final res = await _dio.post(
      '/v1/reseller/wallet/transactions',
      data: await _withCredentials({}),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final list = (data['transactions'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final res = await _dio.post(
      '/v1/reseller/orders/list',
      data: await _withCredentials({}),
    );
    final data = res.data;
    final list = data is List
        ? data
        : ((data as Map)['value'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> searchProducts({
    String? search,
    int page = 0,
    int size = 20,
  }) async {
    final res = await _dio.post(
      '/v1/reseller/products/search',
      data: await _withCredentials({
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'size': size,
      }),
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> payload,
    String idempotencyKey,
  ) async {
    final res = await _dio.post(
      '/v1/reseller/orders',
      data: await _withCredentials({
        ...payload,
        'idempotencyKey': idempotencyKey,
      }),
      // React/Axios has no response timeout by default. Fulfillment can take
      // longer than the 30s timeout used for normal reseller dashboard calls.
      options: Options(receiveTimeout: Duration.zero),
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchOrderDetails(String orderNumber) async {
    final res = await _dio.post(
      '/v1/reseller/orders/details',
      data: await _withCredentials({'orderNumber': orderNumber}),
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final res = await _dio.post(
      '/v1/reseller/profile',
      data: await _withCredentials({}),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final profile = data['profile'];
    if (profile is Map) return profile.cast<String, dynamic>();
    return data;
  }
}
