import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../models/biometric_models.dart';

abstract interface class BiometricKeyStore {
  Future<BiometricAvailability> availability();

  Future<bool> hasKey();

  Future<String> createKeyPair();

  Future<String> signChallenge(String challenge);

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
        reason: 'Biometric login is not supported on this platform.',
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
  Future<String> signChallenge(String challenge) async {
    try {
      final signature = await _channel.invokeMethod<String>('signChallenge', {
        'challenge': challenge,
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
      'biometric_lockout' => const BiometricException(
        'Biometrics are temporarily locked. Unlock your device and try again.',
      ),
      'biometric_unavailable' => BiometricException(
        error.message ?? 'Biometrics are unavailable. Use OTP login instead.',
      ),
      'key_missing' => const BiometricException(
        'The biometric key is missing. Sign in with OTP and enable biometrics again.',
      ),
      'key_invalidated' => const BiometricException(
        'The biometric key was invalidated, possibly after biometric settings changed. Sign in with OTP and enroll again.',
      ),
      _ => BiometricException(
        error.message ?? 'Biometric authentication failed. Use OTP login.',
      ),
    };
  }
}
