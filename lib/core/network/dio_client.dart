import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gift360/core/constants/app_constants.dart';

typedef OnSessionExpired = void Function();

class DioClient {
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static OnSessionExpired? onSessionExpired;
  static const _skipExpiryPaths = {'/payment-result'};

  DioClient({required String baseUrl, FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_secureStorage),
      _LogInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  Dio get dio => _dio;

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;

  _AuthInterceptor(this._secureStorage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipGlobalAuth'] == true ||
        options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    final token = await _secureStorage.read(key: 'auth_token');
    if (token != null && token.isNotEmpty) {
      const scheme = 'Bearer';
      options.headers['Authorization'] = '$scheme $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      final shouldSkip = DioClient._skipExpiryPaths.any(
        (p) => path.contains(p),
      );
      if (!shouldSkip) DioClient.onSessionExpired?.call();
    }
    handler.next(err);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      debugPrint('[DIO] → ${options.method} ${options.uri}');
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    assert(() {
      debugPrint(
        '[DIO] ← ${response.statusCode} ${response.requestOptions.uri}',
      );
      return true;
    }());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      final statusCode = err.response?.statusCode;
      debugPrint(
        '[DIO] ✕ ${err.type}'
        '${statusCode == null ? '' : ' HTTP $statusCode'} '
        '${err.requestOptions.uri}',
      );
      return true;
    }());
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      debugPrint(
        '[DIO] underlying error ${err.error.runtimeType}: '
        '${err.error} | ${err.requestOptions.method} '
        '${err.requestOptions.uri}',
      );
      return true;
    }());
    String message;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        break;
      case DioExceptionType.badResponse:
        message = _handleBadResponse(
          err.response?.statusCode,
          err.response?.data,
        );
        break;
      default:
        message = 'Something went wrong. Please try again.';
    }

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        error: message,
        response: err.response,
        type: err.type,
      ),
    );
  }

  String _handleBadResponse(int? statusCode, dynamic data) {
    if (data is Map) {
      final errorCode = data['errorCode']?.toString();
      if (errorCode == 'EMAIL_NOT_VERIFIED') {
        return (data['message'] ??
                'Please verify your email to continue. We have to be able to send your invoice and vouchers.')
            .toString();
      }
      if (errorCode != null && errorCode.startsWith('LOCATION_')) {
        return checkoutLocationErrorMessage(errorCode);
      }
    }
    if (data is Map<String, dynamic> && data.containsKey('message')) {
      return data['message'] as String;
    }
    if (data is String) return data;

    switch (statusCode) {
      case 400:
        return 'Bad request.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 409:
        return data?.toString() ?? 'Conflict.';
      case 500:
        return 'Server error. Please try again.';
      default:
        return 'Error: $statusCode';
    }
  }
}

String checkoutLocationErrorMessage(String errorCode) {
  switch (errorCode) {
    case 'LOCATION_MISSING':
      return 'Please share your location or enter your PIN code to continue.';
    case 'LOCATION_STALE':
      return 'Your location confirmation expired. Please confirm it again.';
    case 'LOCATION_OUTSIDE_INDIA':
      return 'This location is outside India. Please use a valid Indian location or PIN code.';
    case 'LOCATION_PIN_INVALID':
      return 'Enter a valid 6-digit postal PIN code.';
    case 'LOCATION_PIN_NOT_ALLOWED':
      return "This PIN code can't be used for this payment. Please share your location.";
    case 'LOCATION_CONSENT_MISSING':
    case 'LOCATION_NO_CONSENT':
      return 'Please agree to share your location for this payment.';
    default:
      return 'Please share your location or enter your PIN code to continue.';
  }
}
