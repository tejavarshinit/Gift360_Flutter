import 'package:dio/dio.dart';

import 'package:gift360/config/app_config.dart';

/// Exchange the encrypted order reference (`txnid`) from the payment-result
/// URL for the customer's EXISTING session token. Ported from React
/// `api/sessionResumeApi.ts`.
///
/// Deliberately uses a bare Dio (no auth interceptor): it must run without a
/// token, and a 400/404/409/410 here must NOT be treated as a logout.
class SessionResumeApi {
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.brandApiUrl,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Returns `{token, userInfo: {name, email, mobile, clientId}}` or null.
  Future<Map<String, dynamic>?> resume(String txnid) async {
    try {
      final response = await _dio.post('/v1/session/resume', data: {
        'txnid': txnid,
      });
      if (response.data is Map) {
        return (response.data as Map).cast<String, dynamic>();
      }
    } catch (_) {
      // Endpoint unavailable / expired / not owned: stay read-only.
    }
    return null;
  }
}
