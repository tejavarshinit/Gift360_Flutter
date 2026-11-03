import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/data/repositories/device_token_api.dart';

void main() {
  group('DeviceTokenApi', () {
    late Dio dio;
    late RequestOptions? request;
    late int statusCode;
    late Object? responseBody;

    setUp(() {
      request = null;
      statusCode = 200;
      responseBody = '{"success":true}';
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8081'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: statusCode,
                data: responseBody,
              ),
            );
          },
        ),
      );
    });

    test('posts the authenticated profile client ID and token', () async {
      final api = DeviceTokenApi(baseUrl: 'http://localhost:8081', dio: dio);

      await api.register(
        deviceToken: 'fcm-token',
        deviceType: 'ANDROID',
        clientId: 'profile-client-id',
        authToken: 'session-token',
      );

      expect(request?.method, 'POST');
      expect(request?.path, '/api/v1/notification/device-token');
      expect(request?.data, {
        'deviceToken': 'fcm-token',
        'deviceType': 'ANDROID',
        'uniqueId': 'profile-client-id',
      });
      expect(request?.headers['Authorization'], 'Bearer session-token');
    });

    test(
      'rejects non-200 responses, malformed JSON, and success false',
      () async {
        final api = DeviceTokenApi(baseUrl: 'http://localhost:8081', dio: dio);

        statusCode = 503;
        await expectLater(
          _register(api),
          throwsA(isA<DeviceTokenRegistrationException>()),
        );

        statusCode = 200;
        responseBody = '{invalid';
        await expectLater(
          _register(api),
          throwsA(isA<DeviceTokenRegistrationException>()),
        );

        responseBody = '{"success":false}';
        await expectLater(
          _register(api),
          throwsA(isA<DeviceTokenRegistrationException>()),
        );
      },
    );

    test('rejects a valid JSON response without a success object', () async {
      responseBody = '[]';
      final api = DeviceTokenApi(baseUrl: 'http://localhost:8081', dio: dio);

      await expectLater(
        _register(api),
        throwsA(isA<DeviceTokenRegistrationException>()),
      );
    });
  });
}

Future<void> _register(DeviceTokenApi api) {
  return api.register(
    deviceToken: 'fcm-token',
    deviceType: 'IOS',
    clientId: 'client-id',
    authToken: 'session-token',
  );
}
