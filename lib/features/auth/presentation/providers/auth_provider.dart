import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/core/utils/jwt_utils.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/data/models/biometric_models.dart';
import 'package:gift360/features/auth/data/repositories/auth_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/supercoin/data/repositories/supercoin_api.dart';

class AuthNotifier extends StateNotifier<AuthUser?> {
  final FlutterSecureStorage _secureStorage;
  final AuthApi _authApi;
  final Dio? _brandsDio;
  bool _initialized = false;

  AuthNotifier(this._secureStorage, this._authApi, [this._brandsDio])
    : super(null) {
    _loadUser();
  }

  /// True once any previous authenticated session has been cleared at startup.
  bool get initialized => _initialized;

  Future<void> _loadUser() async {
    try {
      await _secureStorage.delete(key: 'auth_user');
    } catch (error) {
      debugPrint('Could not clear the previous user session: $error');
    }
    try {
      await _secureStorage.delete(key: 'auth_token');
    } catch (error) {
      debugPrint('Could not clear the previous auth token: $error');
    } finally {
      _initialized = true;
    }
  }

  bool get isAuthenticated => state != null;

  void setUser(AuthUser? user) {
    state = user;
    _persistUser(user);
  }

  /// Immediately after login/register, fetch the customer's live SuperCoin
  /// balance and POST it into `client_profile.supercoin_balance`
  /// (POST /v1/clients/supercoin-balance) — the same snapshot React's
  /// fetchSuperCoinBalance persists on every balance fetch while logged in.
  /// Non-Flipkart users (upstream 404) store "NA". Fire-and-forget.
  void _syncSuperCoinBalanceOnAuth(String clientId, String? mobile) {
    final dio = _brandsDio;
    if (dio == null || clientId.trim().isEmpty) return;
    final normalized = _normalizeMobile(mobile);
    if (normalized == null) return;
    final api = SuperCoinApi(dio);
    Future<void>(() async {
      try {
        final result = await api.fetchBalance(
          SuperCoinIdentity(identifier: normalized, type: 'MOBILE'),
        );
        await api.syncBalance(clientId, _extractBalance(result));
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          await api.syncBalance(clientId, 'NA');
        }
      } catch (_) {
        // Balance sync must never break the login flow.
      }
    });
  }

  String? _normalizeMobile(String? mobile) {
    if (mobile == null || mobile.trim().isEmpty) return null;
    final trimmed = mobile.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (trimmed.startsWith('+')) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits.isEmpty ? null : '+$digits';
  }

  double _extractBalance(Map<String, dynamic> response) {
    for (final key in [
      'balance',
      'totalBalance',
      'availableBalance',
      'amount',
    ]) {
      final value = response[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  Future<SendOtpResponse> sendOtp(SendOtpRequest request) async {
    return _authApi.sendOtp(request);
  }

  Future<LoginResponse> loginWithOtp(LoginWithOtpRequest request) async {
    final response = await _authApi.loginWithOtp(request);
    if (response.success &&
        response.token != null &&
        response.userInfo != null) {
      final user = AuthUser(
        name: response.userInfo!.name,
        email: response.userInfo!.email,
        mobile: response.userInfo!.mobile,
        token: response.token!,
        clientId:
            extractClientIdFromToken(response.token!) ??
            response.userInfo!.clientId.trim(),
      );
      await _establishSession(user);
    }
    return response;
  }

  Future<void> loginWithBiometrics(BiometricLoginResult result) async {
    final token = result.token.trim();
    final clientId = result.clientId.trim();
    if (token.isEmpty || clientId.isEmpty) {
      throw const BiometricException(
        'The biometric service did not return a valid authenticated session.',
      );
    }
    await _establishSession(
      AuthUser(
        name: result.name,
        email: result.email,
        mobile: result.mobile,
        token: token,
        clientId: clientId,
      ),
    );
  }

  Future<void> _establishSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSuperCoinIntro', true);
    await _persistUser(user);
    state = user;
    _syncSuperCoinBalanceOnAuth(user.clientId, user.mobile);
    _requestFirstLoginSuperCoinReward(user);
  }

  void _requestFirstLoginSuperCoinReward(AuthUser user) {
    final dio = _brandsDio;
    if (dio == null) return;
    unawaited(
      Future<void>(() async {
        try {
          final deviceId = await _getOrCreateDeviceId();
          final result = await SuperCoinApi(
            dio,
          ).awardFirstLoginReward(deviceId);
          if (result['credited'] == true) {
            _syncSuperCoinBalanceOnAuth(user.clientId, user.mobile);
          }
        } on DioException catch (error) {
          debugPrint(
            '[SuperCoin] First-login reward request failed'
            '${error.response?.statusCode == null ? '' : ' (HTTP ${error.response!.statusCode})'}.',
          );
        } catch (error) {
          debugPrint(
            '[SuperCoin] First-login reward request failed (${error.runtimeType}).',
          );
        }
      }),
    );
  }

  Future<String> _getOrCreateDeviceId() async {
    const key = 'gift360_device_id';
    final existing = await _secureStorage.read(key: key);
    if (existing != null && _isUuid(existing)) return existing;
    final deviceId = _generateDeviceId();
    await _secureStorage.write(key: key, value: deviceId);
    return deviceId;
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<SendOtpResponse> registerSendOtp({
    required String mobileNumber,
    required String email,
  }) async {
    return _authApi.registerSendOtp(mobileNumber: mobileNumber, email: email);
  }

  Future<LoginResponse> registerVerifyOtp({
    required String fullName,
    required String email,
    required String mobileNumber,
    required String otp,
  }) async {
    final response = await _authApi.registerVerifyOtp(
      fullName: fullName,
      email: email,
      mobileNumber: mobileNumber,
      otp: otp,
    );
    if (response.token != null && response.userInfo != null) {
      final user = AuthUser(
        name: response.userInfo!.name,
        email: response.userInfo!.email,
        mobile: response.userInfo!.mobile,
        token: response.token!,
        clientId:
            extractClientIdFromToken(response.token!) ??
            response.userInfo!.clientId.trim(),
      );
      await _establishSession(user);
    }
    return response;
  }

  void updateToken(String token) {
    if (state != null) {
      state = state!.copyWith(token: token);
      _persistUser(state);
    }
  }

  Future<void> _persistUser(AuthUser? user) async {
    if (user != null) {
      final jsonStr = const JsonEncoder().convert(user.toJson());
      await _secureStorage.write(key: 'auth_user', value: jsonStr);
      await _secureStorage.write(key: 'auth_token', value: user.token);
    } else {
      await _secureStorage.delete(key: 'auth_user');
      await _secureStorage.delete(key: 'auth_token');
    }
  }

  Future<void> logout() async {
    state = null;
    await _secureStorage.delete(key: 'auth_user');
    await _secureStorage.delete(key: 'auth_token');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthUser?>((ref) {
  return AuthNotifier(
    const FlutterSecureStorage(),
    ref.watch(authApiProvider),
    ref.watch(brandsDioProvider),
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

/// True once any previous authenticated session has been cleared at startup.
final authInitializedProvider = Provider<bool>((ref) {
  final notifier = ref.watch(authProvider.notifier);
  return notifier.initialized;
});
