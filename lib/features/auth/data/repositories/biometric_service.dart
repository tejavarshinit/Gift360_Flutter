import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/biometric_models.dart';
import 'biometric_api.dart';
import 'biometric_key_store.dart';

class BiometricService {
  static const _enabledKey = 'biometric_login_enabled';
  static const _deviceIdKey = 'biometric_login_device_id';
  static const _clientIdKey = 'biometric_login_client_id';

  final BiometricApi _api;
  final BiometricKeyStore _keyStore;
  final BiometricStorage _storage;
  final DateTime Function() _now;
  final String Function() _newDeviceId;

  BiometricService({
    required BiometricApi api,
    required BiometricKeyStore keyStore,
    required BiometricStorage storage,
    DateTime Function()? now,
    String Function()? newDeviceId,
  }) : _api = api,
       _keyStore = keyStore,
       _storage = storage,
       _now = now ?? DateTime.now,
       _newDeviceId = newDeviceId ?? _generateDeviceId;

  Future<BiometricEnrollmentState> enrollmentState() async {
    try {
      final enabled = await _storage.read(_enabledKey);
      if (enabled != 'true') return const BiometricEnrollmentState();
      final deviceId = await _storage.read(_deviceIdKey);
      final clientId = await _storage.read(_clientIdKey);
      if (deviceId == null ||
          deviceId.trim().isEmpty ||
          clientId == null ||
          clientId.trim().isEmpty) {
        return const BiometricEnrollmentState(
          issue:
              'Biometric enrollment data is incomplete. Sign in with OTP and enroll again.',
        );
      }
      if (!await _keyStore.hasKey()) {
        return const BiometricEnrollmentState(
          issue:
              'The protected biometric key is missing or invalidated. Sign in with OTP and enroll again.',
        );
      }
      return BiometricEnrollmentState(
        enrollment: BiometricEnrollment(deviceId: deviceId, clientId: clientId),
      );
    } on BiometricException catch (error) {
      return BiometricEnrollmentState(issue: error.message);
    }
  }

  Future<BiometricAvailability> availability() => _keyStore.availability();

  Future<void> enable({required String clientId, required String token}) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty || token.trim().isEmpty) {
      throw const BiometricException(
        'A valid signed-in account is required to enable biometric login.',
      );
    }
    final current = await enrollmentState();
    if (current.isEnabled) {
      if (current.enrollment!.clientId == normalizedClientId) return;
      throw const BiometricException(
        'Biometric login is enrolled for another account. Sign in to that account and disable biometrics before switching enrollment.',
      );
    }
    if (current.issue != null) throw BiometricException(current.issue!);

    final availability = await _keyStore.availability();
    if (!availability.supported || !availability.enrolled) {
      throw BiometricException(
        availability.reason ??
            'Set up a device biometric before enabling biometric login.',
      );
    }
    if (await _keyStore.hasKey()) {
      throw const BiometricException(
        'A protected biometric key exists without matching enrollment data. Sign in with OTP and contact support before enrolling again.',
      );
    }

    final deviceId = _newDeviceId();
    await _storage.write(_deviceIdKey, deviceId);
    var keyCreated = false;
    var registered = false;
    try {
      final publicKey = await _keyStore.createKeyPair();
      keyCreated = true;
      await _api.register(
        clientId: normalizedClientId,
        deviceId: deviceId,
        publicKey: publicKey,
        token: token,
      );
      registered = true;
      await _storage.write(_clientIdKey, normalizedClientId);
      await _storage.write(_enabledKey, 'true');
    } catch (error) {
      var cleanupFailed = false;
      if (registered) {
        try {
          await _api.revoke(deviceId: deviceId, token: token);
        } on Object {
          cleanupFailed = true;
        }
      }
      if (keyCreated) {
        try {
          await _keyStore.deleteKey();
        } on Object {
          cleanupFailed = true;
        }
      }
      try {
        await _clearMetadata();
      } on Object {
        cleanupFailed = true;
      }
      if (cleanupFailed) {
        throw const BiometricException(
          'Biometric enrollment failed and cleanup could not be fully confirmed. Use OTP login and contact support before trying again.',
        );
      }
      rethrow;
    }
  }

  Future<BiometricLoginResult> login() async {
    final state = await enrollmentState();
    if (!state.isEnabled) {
      throw BiometricException(
        state.issue ?? 'Biometric login has not been enabled on this device.',
      );
    }
    final enrollment = state.enrollment!;
    final challenge = await _api.challenge(enrollment.deviceId);
    final deadline = _now().add(Duration(seconds: challenge.expiresIn));
    if (!_now().isBefore(deadline)) {
      throw const BiometricException(
        'The biometric challenge expired. Please try again.',
      );
    }
    final signature = await _keyStore.signChallenge(challenge.value);
    if (!_now().isBefore(deadline)) {
      throw const BiometricException(
        'The biometric challenge expired. Please try again.',
      );
    }
    final result = await _api.login(
      challengeId: challenge.id,
      deviceId: enrollment.deviceId,
      signature: signature,
    );
    if (result.clientId != enrollment.clientId) {
      throw const BiometricException(
        'This device is enrolled for a different account. Use OTP login or disable biometrics from the enrolled account.',
      );
    }
    return result;
  }

  Future<void> disable({
    required String clientId,
    required String token,
  }) async {
    final state = await enrollmentState();
    if (state.issue != null) throw BiometricException(state.issue!);
    final enrollment = state.enrollment;
    if (enrollment == null) return;
    if (enrollment.clientId != clientId.trim()) {
      throw const BiometricException(
        'Only the account that enabled biometric login can disable it.',
      );
    }
    await _api.revoke(deviceId: enrollment.deviceId, token: token);
    await _keyStore.deleteKey();
    await _clearMetadata();
  }

  Future<void> recoverAfterOtp({
    required String clientId,
    required String token,
  }) async {
    final normalizedClientId = clientId.trim();
    final deviceId = await _storage.read(_deviceIdKey);
    final enrolledClientId = await _storage.read(_clientIdKey);
    if (normalizedClientId.isEmpty ||
        token.trim().isEmpty ||
        deviceId == null ||
        deviceId.trim().isEmpty ||
        enrolledClientId != normalizedClientId) {
      throw const BiometricException(
        'The biometric enrollment cannot be safely removed for this account. Contact support or sign in to the enrolled account.',
      );
    }
    await _api.revoke(deviceId: deviceId, token: token);
    await _keyStore.deleteKey();
    await _clearMetadata();
  }

  Future<void> _clearMetadata() async {
    await _storage.delete(_enabledKey);
    await _storage.delete(_deviceIdKey);
    await _storage.delete(_clientIdKey);
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

abstract interface class BiometricStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterBiometricStorage implements BiometricStorage {
  final FlutterSecureStorage _storage;

  FlutterBiometricStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

String? biometricGatewayOrigin(String configuredBrandApiUrl) {
  final uri = Uri.tryParse(configuredBrandApiUrl.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}
