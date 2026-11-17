import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/auth/data/models/biometric_models.dart';

/// App lock: user-set MPIN + device biometric to unlock a restored session.
class AppLockService {
  static const _channel = MethodChannel('com.gift360.gift360/biometric');
  static const _mpinHashKey = 'app_lock_mpin_hash';
  static const _biometricPref = 'app_lock_biometric_enabled';
  static const _mpinPref = 'app_lock_mpin_enabled';

  final FlutterSecureStorage _secureStorage;

  AppLockService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricPref) ?? false;
  }

  Future<bool> isMpinLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_mpinPref) ?? false;
    final hash = await _secureStorage.read(key: _mpinHashKey);
    final hasPin = hash != null && hash.isNotEmpty;
    // Pref on without a real PIN — clear the orphaned flag.
    if (enabled && !hasPin) {
      await prefs.setBool(_mpinPref, false);
      return false;
    }
    // Hash without pref — treat as enabled only if pin exists.
    if (!enabled && hasPin) {
      await prefs.setBool(_mpinPref, true);
      await prefs.setBool('login_method_mpin_enabled', true);
      return true;
    }
    return enabled && hasPin;
  }

  Future<bool> hasMpinSet() async {
    final hash = await _secureStorage.read(key: _mpinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> requiresLock() async {
    final bio = await isBiometricLockEnabled();
    final mpin = await isMpinLockEnabled();
    return bio || mpin;
  }

  /// Clears MPIN if the user never finished setup (no stored PIN).
  Future<void> clearMpinIfUnset() async {
    if (!await hasMpinSet()) {
      await setMpinLockEnabled(false);
    }
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPref, enabled);
    // Keep login-method toggle in sync with profile UI.
    await prefs.setBool('login_method_biometric_enabled', enabled);
  }

  Future<void> setMpinLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mpinPref, enabled);
    await prefs.setBool('login_method_mpin_enabled', enabled);
    if (!enabled) {
      await _secureStorage.delete(key: _mpinHashKey);
    }
  }

  Future<void> setMpin(String pin) async {
    final normalized = pin.trim();
    if (!_isValidPin(normalized)) {
      throw const BiometricException('MPIN must be 4 digits.');
    }
    final hash = sha256.convert(utf8.encode('gift360_mpin:$normalized')).toString();
    await _secureStorage.write(key: _mpinHashKey, value: hash);
    await setMpinLockEnabled(true);
  }

  Future<bool> verifyMpin(String pin) async {
    final hash = await _secureStorage.read(key: _mpinHashKey);
    if (hash == null || hash.isEmpty) return false;
    final attempt =
        sha256.convert(utf8.encode('gift360_mpin:${pin.trim()}')).toString();
    return hash == attempt;
  }

  Future<void> authenticateWithBiometrics({
    String reason = 'Unlock Gift360',
  }) async {
    if (kIsWeb) {
      throw const BiometricException('Biometric unlock is not available on web.');
    }
    try {
      final ok = await _channel.invokeMethod<bool>('authenticate', {
        'reason': reason,
      });
      if (ok != true) {
        throw const BiometricException('Biometric unlock failed.');
      }
    } on PlatformException catch (error) {
      throw BiometricException(
        error.message ?? 'Biometric unlock failed. Try MPIN instead.',
      );
    }
  }

  bool _isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);
}
