import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../models/biometric_models.dart';

abstract interface class BiometricKeyStore {
  Future<BiometricAvailability> availability();

  Future<bool> hasKey();

  Future<String> createKeyPair();

  Future<String> signChallenge(
    String challenge, {
    DeviceAuthMethod method = DeviceAuthMethod.any,
  });

  Future<void> deleteKey();
}

class PlatformBiometricKeyStore implements BiometricKeyStore {
  static const MethodChannel _channel = MethodChannel(
    'com.gift360.gift360/biometric',
  );

  @override
  Future<BiometricAvailability> availability() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return const BiometricAvailability(
        supported: false,
        enrolled: false,
        reason: 'Device-lock login is not supported on this platform.',
      );
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'availability',
      );
      if (result == null) {
        throw const BiometricException(
          'Could not check biometric availability.',
        );
      }
      return BiometricAvailability(
        supported: result['supported'] == true,
        enrolled: result['enrolled'] == true,
        reason: result['reason'] as String?,
        biometricAvailable: result['biometricAvailable'] != false,
        credentialAvailable: result['credentialAvailable'] != false,
      );
    } on PlatformException catch (error) {
      throw _platformError(error);
    }
  }

  @override
  Future<bool> hasKey() async {
    try {
      return await _channel.invokeMethod<bool>('hasKey') ?? false;
    } on PlatformException catch (error) {
      throw _platformError(error);
    }
  }

  @override
  Future<String> createKeyPair() async {
    try {
      final publicKey = await _channel.invokeMethod<String>('createKeyPair');
      if (publicKey == null || publicKey.trim().isEmpty) {
        throw const BiometricException(
          'The device could not create a protected biometric key.',
        );
      }
      return publicKey;
    } on PlatformException catch (error) {
      throw _platformError(error);
    }
  }

  @override
  Future<String> signChallenge(
    String challenge, {
    DeviceAuthMethod method = DeviceAuthMethod.any,
  }) async {
    try {
      final signature = await _channel.invokeMethod<String>('signChallenge', {
        'challenge': challenge,
        'method': method.name,
      });
      if (signature == null || signature.isEmpty) {
        throw const BiometricException(
          'Biometric verification did not return a signature.',
        );
      }
      return signature;
    } on PlatformException catch (error) {
      throw _platformError(error);
    }
  }

  @override
  Future<void> deleteKey() async {
    try {
      await _channel.invokeMethod<void>('deleteKey');
    } on PlatformException catch (error) {
      throw _platformError(error);
    }
  }

  BiometricException _platformError(PlatformException error) {
    return switch (error.code) {
      'biometric_cancelled' => const BiometricException(
        'Biometric authentication was cancelled.',
      ),
      'device_credential_cancelled' => const BiometricException(
        'Device unlock was cancelled.',
      ),
      'biometric_lockout' => const BiometricException(
        'Device lock is temporarily locked. Unlock your device and try again.',
      ),
      'device_credential_unavailable' => BiometricException(
        error.message ??
            'Device-lock authentication is unavailable. Use OTP login instead.',
      ),
      'biometric_unavailable' => BiometricException(
        error.message ??
            'Device-lock authentication is unavailable. Use OTP login instead.',
      ),
      'key_missing' => const BiometricException(
        'The device-lock key is missing. Sign in with OTP and enable device-lock login again.',
      ),
      'key_invalidated' => const BiometricException(
        'The device-lock key was invalidated, possibly after the screen lock or biometrics changed. Sign in with OTP and enroll again.',
      ),
      'key_not_authorized' => const BiometricException(
        'Device unlock verification expired. Please try again.',
      ),
      _ => BiometricException(
        error.message ?? 'Device-lock authentication failed. Use OTP login.',
      ),
    };
  }
}
