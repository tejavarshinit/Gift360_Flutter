import 'package:dio/dio.dart';

import '../models/biometric_models.dart';

class BiometricApi {
  final Dio _dio;

  BiometricApi(this._dio);

  Future<void> register({
    required String clientId,
    required String deviceId,
    required String publicKey,
    required String token,
  }) async {
    final response = await _post('/api/v1/auth/biometric/register', {
      'uniqueId': clientId,
      'deviceId': deviceId,
      'publicKey': publicKey,
    }, token: token);
    _requireSuccess(response, 'Biometric registration failed.');
  }

  Future<BiometricChallenge> challenge(String deviceId) async {
    final response = await _post('/api/v1/auth/biometric/challenge', {
      'deviceId': deviceId,
    }, publicRequest: true);
    final json = _requireSuccess(response, 'Could not get a login challenge.');
    final challengeId = _nonblank(json['challengeId']);
    final challenge = _nonblank(json['challenge']);
    final expiresIn = json['expiresIn'];
    if (challengeId == null ||
        challenge == null ||
        expiresIn is! num ||
        expiresIn <= 0 ||
        expiresIn > 300) {
      throw const BiometricException(
        'The biometric service returned an invalid challenge.',
      );
    }
    return BiometricChallenge(
      id: challengeId,
      value: challenge,
      expiresIn: expiresIn.toInt(),
    );
  }

  Future<BiometricLoginResult> login({
    required String challengeId,
    required String deviceId,
    required String signature,
  }) async {
    final response = await _post('/api/v1/auth/biometric/login', {
      'challengeId': challengeId,
      'deviceId': deviceId,
      'signature': signature,
    }, publicRequest: true);
    final json = _requireSuccess(response, 'Biometric login failed.');
    final token = _nonblank(json['token']);
    final userInfo = json['userInfo'];
    if (token == null || userInfo is! Map) {
      throw const BiometricException(
        'The biometric service returned an incomplete login response.',
      );
    }
    final clientId = _nonblank(userInfo['clientId']);
    if (clientId == null) {
      throw const BiometricException(
        'The biometric service returned no authenticated client ID.',
      );
    }
    return BiometricLoginResult(
      token: token,
      clientId: clientId,
      name: _string(userInfo['name']),
      email: _string(userInfo['email']),
      mobile: _string(userInfo['mobile']),
    );
  }

  Future<void> revoke({required String deviceId, required String token}) async {
    final response = await _post('/api/v1/auth/biometric/revoke', {
      'deviceId': deviceId,
    }, token: token);
    _requireSuccess(response, 'Could not disable biometric login.');
  }

  Future<dynamic> _post(
    String path,
    Map<String, Object> body, {
    String? token,
    bool publicRequest = false,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          headers: {
            if (token != null) 'Authorization': _authorizationHeader(token),
          },
          extra: {if (publicRequest) 'skipGlobalAuth': true},
        ),
      );
      return response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        throw BiometricException(
          'Biometric service rejected the request (HTTP $statusCode). '
          'If this persists, check the signed-in session and gateway configuration.',
        );
      }
      throw const BiometricException(
        'Biometric service request failed. Check your connection and try again.',
      );
    }
  }

  Map<String, dynamic> _requireSuccess(dynamic response, String message) {
    if (response is! Map) throw BiometricException(message);
    final json = <String, dynamic>{};
    for (final entry in response.entries) {
      if (entry.key is! String) throw BiometricException(message);
      json[entry.key as String] = entry.value;
    }
    if (json['success'] != true) throw BiometricException(message);
    return json;
  }

  String? _nonblank(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _string(dynamic value) => value is String ? value : '';

  String _authorizationHeader(String token) {
    const scheme = 'Bearer';
    return '$scheme $token';
  }
}

class BiometricChallenge {
  final String id;
  final String value;
  final int expiresIn;

  const BiometricChallenge({
    required this.id,
    required this.value,
    required this.expiresIn,
  });
}
