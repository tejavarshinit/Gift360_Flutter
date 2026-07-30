import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gift360/core/utils/jwt_utils.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/auth/data/repositories/auth_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';

class AuthNotifier extends StateNotifier<AuthUser?> {
  final FlutterSecureStorage _secureStorage;
  final AuthApi _authApi;

  AuthNotifier(this._secureStorage, this._authApi) : super(null) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final userJson = await _secureStorage.read(key: 'auth_user');
      if (userJson != null) {
        var user = AuthUser.fromJson(
          Map<String, dynamic>.from(
            const JsonDecoder().convert(userJson) as Map,
          ),
        );
        if (user.clientId.trim().isEmpty && user.token.isNotEmpty) {
          final clientId = extractClientIdFromToken(user.token);
          if (clientId != null) {
            user = user.copyWith(clientId: clientId);
            _persistUser(user);
          }
        }
        state = user;
      }
    } catch (e) {
      print('🔐 _loadUser error: $e');
      state = null;
    }
  }

  bool get isAuthenticated => state != null;

  void setUser(AuthUser? user) {
    state = user;
    _persistUser(user);
  }

  Future<SendOtpResponse> sendOtp(SendOtpRequest request) async {
    return _authApi.sendOtp(request);
  }

  Future<LoginResponse> loginWithOtp(LoginWithOtpRequest request) async {
    final response = await _authApi.loginWithOtp(request);
    if (response.success && response.token != null && response.userInfo != null) {
      final user = AuthUser(
        name: response.userInfo!.name,
        email: response.userInfo!.email,
        mobile: response.userInfo!.mobile,
        token: response.token!,
        clientId: extractClientIdFromToken(response.token!) ?? response.userInfo!.clientId.trim(),
      );
      setUser(user);
    }
    return response;
  }

  Future<SendOtpResponse> registerSendOtp({
    required String mobileNumber,
    required String email,
  }) async {
    return _authApi.registerSendOtp(
      mobileNumber: mobileNumber,
      email: email,
    );
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
        clientId: extractClientIdFromToken(response.token!) ?? response.userInfo!.clientId.trim(),
      );
      setUser(user);
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
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

