import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';
import 'package:gift360/features/auth/data/repositories/auth_api.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final values = <String, String>{
    'biometric_login_enabled': 'true',
    'biometric_login_device_id': 'device-1',
    'biometric_login_client_id': 'client-1',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    values
      ..clear()
      ..addAll({
        'biometric_login_enabled': 'true',
        'biometric_login_device_id': 'device-1',
        'biometric_login_client_id': 'client-1',
      });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : values[key];
            case 'write':
              values[key!] = arguments['value'] as String;
              return null;
            case 'delete':
              values.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test(
    'biometric login persists the normal authenticated session; logout retains enrollment',
    () async {
      final notifier = AuthNotifier(
        const FlutterSecureStorage(),
        AuthApi(Dio()),
      );
      await Future<void>.delayed(Duration.zero);

      await notifier.loginWithBiometrics(
        const BiometricLoginResult(
          token: 'new-auth-token',
          clientId: 'client-1',
          name: 'User',
          email: 'user@example.test',
          mobile: '1234567890',
        ),
      );

      expect(notifier.state?.clientId, 'client-1');
      expect(values['auth_token'], 'new-auth-token');
      expect(values['auth_user'], isNotNull);

      await notifier.logout();

      expect(values.containsKey('auth_token'), isFalse);
      expect(values.containsKey('auth_user'), isFalse);
      expect(values['biometric_login_enabled'], 'true');
      expect(values['biometric_login_device_id'], 'device-1');
      expect(values['biometric_login_client_id'], 'client-1');
      notifier.dispose();
    },
  );

  test(
    'biometric session handoff rejects missing backend identity or token',
    () async {
      final notifier = AuthNotifier(
        const FlutterSecureStorage(),
        AuthApi(Dio()),
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        notifier.loginWithBiometrics(
          const BiometricLoginResult(
            token: ' ',
            clientId: 'client-1',
            name: '',
            email: '',
            mobile: '',
          ),
        ),
        throwsA(isA<BiometricException>()),
      );
      expect(notifier.state, isNull);
      expect(values.containsKey('auth_token'), isFalse);
      notifier.dispose();
    },
  );

  test(
    'startup clears the previous login session but retains biometric data',
    () async {
      values
        ..['auth_token'] = 'previous-token'
        ..['auth_user'] = '{"token":"previous-token","clientId":"client-1"}';
      final notifier = AuthNotifier(
        const FlutterSecureStorage(),
        AuthApi(Dio()),
      );

      await Future<void>.delayed(Duration.zero);

      expect(notifier.initialized, isTrue);
      expect(notifier.state, isNull);
      expect(values.containsKey('auth_token'), isFalse);
      expect(values.containsKey('auth_user'), isFalse);
      expect(values['biometric_login_enabled'], 'true');
      notifier.dispose();
    },
  );
}
