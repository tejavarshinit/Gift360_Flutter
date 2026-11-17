import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/config/app_flavor.dart';
import 'package:gift360/config/dev_session.dart';
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
      final jsonStr = await _secureStorage.read(key: 'auth_user');
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final map = jsonDecode(jsonStr);
        if (map is Map<String, dynamic>) {
          final user = AuthUser.fromJson(map);
          if (user.token.trim().isNotEmpty && user.clientId.trim().isNotEmpty) {
            state = user;
          }
        }
      }
    } catch (error) {
      debugPrint('Could not restore the previous user session: $error');
    } finally {
      _initialized = true;
      // Nudge listeners (router / app lock) even when session is null.
      state = state;
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
    if (AppFlavorConfig.isDev) return;
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
    if (AppFlavorConfig.usesMockOtp) {
      return const SendOtpResponse(
        success: true,
        message: 'Dev build: enter OTP 1234. No SMS is sent.',
      );
    }
    return _authApi.sendOtp(request);
  }

  Future<LoginResponse> loginWithOtp(LoginWithOtpRequest request) async {
    if (AppFlavorConfig.usesMockOtp) {
      return _loginWithDevOtp(
        mobile: request.mobileNumber,
        otp: request.otp,
      );
    }
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

  Future<LoginResponse> _loginWithDevOtp({
    required String mobile,
    required String otp,
    String name = 'Dev User',
    String? email,
  }) async {
    if (otp != AppFlavorConfig.devOtp) {
      return const LoginResponse(
        success: false,
        message: 'Dev OTP is 1234.',
      );
    }
    final user = devAuthUser(mobile: mobile, name: name, email: email);
    await _establishSession(user);
    return devLoginResponse(user);
  }

  Future<void> _establishSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showSuperCoinIntro', true);
    await _persistUser(user);
    state = user;
    _syncSuperCoinBalanceOnAuth(user.clientId, user.mobile);
  }

  void refreshSuperCoinBalance() {
    final user = state;
    if (user != null) {
      _syncSuperCoinBalanceOnAuth(user.clientId, user.mobile);
    }
  }

  Future<SendOtpResponse> registerSendOtp({
    required String mobileNumber,
    required String email,
  }) async {
    if (AppFlavorConfig.usesMockOtp) {
      return const SendOtpResponse(
        success: true,
        message: 'Dev build: enter OTP 1234. No SMS is sent.',
      );
    }
    return _authApi.registerSendOtp(mobileNumber: mobileNumber, email: email);
  }

  Future<LoginResponse> registerVerifyOtp({
    required String fullName,
    required String email,
    required String mobileNumber,
    required String otp,
  }) async {
    if (AppFlavorConfig.usesMockOtp) {
      return _loginWithDevOtp(
        mobile: mobileNumber,
        otp: otp,
        name: fullName,
        email: email,
      );
    }
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

/// True once session restore from secure storage has finished.
final authInitializedProvider = Provider<bool>((ref) {
  // Rebuild when auth state settles so router redirect re-runs.
  ref.watch(authProvider);
  return ref.read(authProvider.notifier).initialized;
});

/// When true, stay on /login after OTP so biometric + MPIN setup can finish.
final postLoginSetupHoldingProvider = StateProvider<bool>((ref) => false);
