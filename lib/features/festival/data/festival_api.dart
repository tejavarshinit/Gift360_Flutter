import 'package:dio/dio.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/festival/data/models/festival_config.dart';

/// Fetches festival theme from backend when available.
/// Until the API exists, callers always fall back to [FestivalConfig.defaults].
class FestivalApi {
  FestivalApi(this._dio);

  final Dio _dio;

  /// Expected endpoint (backend can implement later):
  /// `GET {BRAND_API_URL}/v1/app/festival-config`
  Future<FestivalConfig?> fetchActive() async {
    final base = AppConfig.brandApiUrl.trim();
    if (base.isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$base/v1/app/festival-config',
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      if (response.statusCode == 404 || response.data == null) return null;
      if (response.statusCode != 200) return null;
      return FestivalConfig.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }
}
