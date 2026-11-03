import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/auth/data/repositories/biometric_key_store.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.gift360.gift360/biometric');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'platform cancellation is surfaced as a usable fallback error',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'biometric_cancelled',
              message: 'Biometric authentication was cancelled.',
            );
          });

      await expectLater(
        PlatformBiometricKeyStore().signChallenge('exact challenge'),
        throwsA(
          isA<BiometricException>().having(
            (error) => error.message,
            'message',
            'Biometric authentication was cancelled.',
          ),
        ),
      );
    },
  );

  test('invalidated protected key provides OTP recovery guidance', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'key_invalidated');
        });

    await expectLater(
      PlatformBiometricKeyStore().hasKey(),
      throwsA(
        isA<BiometricException>().having(
          (error) => error.message,
          'message',
          contains('invalidated'),
        ),
      ),
    );
  });
}
