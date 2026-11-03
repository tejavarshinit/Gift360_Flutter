import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/auth/data/repositories/biometric_api.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';

void main() {
  test('challenge validates the response and sends a public request', () async {
    late RequestOptions request;
    final api = BiometricApi(
      _dio((options) {
        request = options;
        return {
          'success': true,
          'challengeId': 'c1',
          'challenge': 'exact',
          'expiresIn': 300,
        };
      }),
    );

    final challenge = await api.challenge('device-1');

    expect(challenge.id, 'c1');
    expect(challenge.value, 'exact');
    expect(challenge.expiresIn, 300);
    expect(request.path, '/api/v1/auth/biometric/challenge');
    expect(request.extra['skipGlobalAuth'], isTrue);
    expect(request.data, {'deviceId': 'device-1'});
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('challenge rejects unsuccessful and malformed responses', () async {
    for (final body in [
      {'success': false, 'challengeId': 'c', 'challenge': 'v', 'expiresIn': 10},
      {'success': true, 'challengeId': '', 'challenge': 'v', 'expiresIn': 10},
      {'success': true, 'challengeId': 'c', 'challenge': 'v', 'expiresIn': 301},
      {'success': true, 'challengeId': 'c', 'challenge': 'v', 'expiresIn': 0},
    ]) {
      final api = BiometricApi(_dio((_) => body));
      await expectLater(
        api.challenge('device'),
        throwsA(isA<BiometricException>()),
      );
    }
  });

  test(
    'registration sends the authenticated client ID and bearer token',
    () async {
      late RequestOptions request;
      final api = BiometricApi(
        _dio((options) {
          request = options;
          return {'success': true};
        }),
      );

      await api.register(
        clientId: 'client-1',
        deviceId: 'device-1',
        publicKey: 'public-key-base64',
        token: 'auth-token',
      );

      expect(request.path, '/api/v1/auth/biometric/register');
      expect(request.data, {
        'uniqueId': 'client-1',
        'deviceId': 'device-1',
        'publicKey': 'public-key-base64',
      });
      expect(request.headers['Authorization'], 'Bearer auth-token');
    },
  );

  test(
    'login requires a successful response with token and client ID',
    () async {
      final invalid = BiometricApi(
        _dio(
          (_) => {
            'success': true,
            'token': 'auth-token',
            'userInfo': {'clientId': ' '},
          },
        ),
      );
      await expectLater(
        invalid.login(challengeId: 'c', deviceId: 'd', signature: 's'),
        throwsA(isA<BiometricException>()),
      );

      final valid = BiometricApi(
        _dio(
          (_) => {
            'success': true,
            'token': 'auth-token',
            'userInfo': {
              'clientId': 'client-1',
              'name': 'User',
              'email': 'user@example.test',
              'mobile': '123',
            },
          },
        ),
      );
      final result = await valid.login(
        challengeId: 'c',
        deviceId: 'd',
        signature: 'signature',
      );
      expect(result.token, 'auth-token');
      expect(result.clientId, 'client-1');
      expect(result.name, 'User');
    },
  );

  test(
    'malformed transport responses are rejected without exposing bodies',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example'));
      dio.httpClientAdapter = _CallbackAdapter(
        (_) => ResponseBody.fromString(
          'not-json',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final api = BiometricApi(dio);
      await expectLater(
        api.challenge('device'),
        throwsA(isA<BiometricException>()),
      );
    },
  );

  test(
    'HTTP failures expose only the status code, not the response body',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example'));
      dio.httpClientAdapter = _CallbackAdapter(
        (_) => ResponseBody.fromString(
          '{"message":"private backend detail"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final api = BiometricApi(dio);

      await expectLater(
        api.register(
          clientId: 'client',
          deviceId: 'device',
          publicKey: 'public-key',
          token: 'token',
        ),
        throwsA(
          isA<BiometricException>()
              .having((error) => error.message, 'message', contains('HTTP 401'))
              .having(
                (error) => error.message,
                'message',
                isNot(contains('private backend detail')),
              ),
        ),
      );
    },
  );
}

Dio _dio(Map<String, Object?> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example'));
  dio.httpClientAdapter = _CallbackAdapter(
    (options) => ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  return dio;
}

class _CallbackAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) _respond;

  _CallbackAdapter(this._respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _respond(options);

  @override
  void close({bool force = false}) {}
}
