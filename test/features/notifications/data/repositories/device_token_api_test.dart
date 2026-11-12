import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/data/repositories/device_token_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const secureStorage = FlutterSecureStorage();
  var storedToken = 'session-token';

  group('DeviceTokenApi', () {
    late Dio dio;
    late RequestOptions? request;
    late int statusCode;
    late Object? responseBody;

    setUp(() {
      request = null;
      statusCode = 200;
      responseBody = '{"success":true}';
      storedToken = 'session-token';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
            if (call.method == 'read') return storedToken;
            return null;
          });
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

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    });

    test(
      'reads the stored JWT and sends a Bearer authorization header',
      () async {
        final api = DeviceTokenApi(
          baseUrl: 'http://localhost:8081',
          dio: dio,
          secureStorage: secureStorage,
        );

        await api.register(
          deviceToken: 'fcm-token',
          deviceType: 'ANDROID',
          clientId: 'profile-client-id',
        );

        expect(request?.method, 'POST');
        expect(request?.path, '/v1/notification/device-token');
        expect(request?.headers['Authorization'], 'Bearer session-token');
      },
    );

    test('fails clearly when the authenticated token is unavailable', () async {
      storedToken = '';
      final api = DeviceTokenApi(
        baseUrl: 'http://localhost:8081',
        dio: dio,
        secureStorage: secureStorage,
      );

      await expectLater(
        api.register(
          deviceToken: 'fcm-token',
          deviceType: 'ANDROID',
          clientId: 'client-id',
        ),
        throwsA(isA<DeviceTokenRegistrationException>()),
      );
    });

    test(
      'rejects non-200 responses, malformed JSON, and success false',
      () async {
        final api = DeviceTokenApi(
          baseUrl: 'http://localhost:8081',
          dio: dio,
          secureStorage: secureStorage,
        );

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

    test(
      'registration coordinator deduplicates successful tokens per account',
      () async {
        final registrations = <String>[];
        final coordinator = DeviceTokenRegistrationCoordinator((
          token,
          clientId,
        ) async {
          registrations.add('$clientId:$token');
        });

        coordinator.setClientId('client-id');
        await coordinator.register('fcm-token', 'client-id');
        await coordinator.register('fcm-token', 'client-id');
        coordinator.setClientId('another-client');
        await coordinator.register('fcm-token', 'another-client');

        expect(registrations, [
          'client-id:fcm-token',
          'another-client:fcm-token',
        ]);
      },
    );
  });
}

Future<void> _register(DeviceTokenApi api) {
  return api.register(
    deviceToken: 'fcm-token',
    deviceType: 'IOS',
    clientId: 'client-id',
  );
}
