import 'dart:convert';

import 'package:dio/dio.dart';

class DeviceTokenRegistrationException implements Exception {
  final String message;

  const DeviceTokenRegistrationException(this.message);

  @override
  String toString() => 'DeviceTokenRegistrationException: $message';
}

class DeviceTokenApi {
  final Dio _dio;

  DeviceTokenApi({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              contentType: Headers.jsonContentType,
              responseType: ResponseType.plain,
              headers: const {'Accept': 'application/json'},
            ),
          );

  Future<void> register({
    required String deviceToken,
    required String deviceType,
    required String clientId,
    required String authToken,
  }) async {
    final response = await _dio.post<Object?>(
      '/api/v1/notification/device-token',
      data: {
        'deviceToken': deviceToken,
        'deviceType': deviceType,
        'uniqueId': clientId,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $authToken'},
      ),
    );

    if (response.statusCode != 200) {
      throw DeviceTokenRegistrationException(
        'Backend returned HTTP ${response.statusCode ?? 'unknown'}.',
      );
    }

    final dynamic decoded;
    try {
      final data = response.data;
      decoded = data is String ? jsonDecode(data) : data;
    } on FormatException {
      throw const DeviceTokenRegistrationException(
        'Backend returned invalid JSON.',
      );
    }

    if (decoded is! Map || decoded['success'] != true) {
      throw const DeviceTokenRegistrationException(
        'Backend did not confirm device-token registration.',
      );
    }
  }
}

class DeviceTokenRegistrationCoordinator {
  final Future<void> Function(String token, String clientId) _register;
  final Map<String, Future<void>> _inFlight = {};
  Future<void> _queue = Future<void>.value();
  String? _activeClientId;
  String? _lastSuccessfulKey;

  DeviceTokenRegistrationCoordinator(this._register);

  void setClientId(String? clientId) {
    final normalized = clientId?.trim();
    final nextClientId = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (_activeClientId == nextClientId) return;
    _activeClientId = nextClientId;
    _lastSuccessfulKey = null;
  }

  Future<void> register(String token, String clientId) {
    final normalizedClientId = clientId.trim();
    if (token.trim().isEmpty || normalizedClientId.isEmpty) {
      return Future<void>.error(
        ArgumentError(
          'A device token and authenticated client ID are required.',
        ),
      );
    }
    if (_activeClientId != normalizedClientId) return Future<void>.value();

    final key = '$normalizedClientId\u0000$token';
    if (_lastSuccessfulKey == key) return Future<void>.value();
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final request = _queue.then((_) async {
      if (_activeClientId != normalizedClientId || _lastSuccessfulKey == key) {
        return;
      }
      await _register(token, normalizedClientId);
      if (_activeClientId == normalizedClientId) {
        _lastSuccessfulKey = key;
      }
    });
    _inFlight[key] = request;
    _queue = request.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    request.then<void>(
      (_) {
        _inFlight.remove(key);
      },
      onError: (Object _, StackTrace _) {
        _inFlight.remove(key);
      },
    );
    return request;
  }
}
