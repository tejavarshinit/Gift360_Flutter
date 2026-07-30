import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gift360/core/utils/jwt_utils.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi _authApi;
  final FlutterSecureStorage _secureStorage;

  AuthRepository({
    required AuthApi authApi,
    FlutterSecureStorage? secureStorage,
  })  : _authApi = authApi,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<AuthUser?> getStoredUser() async {
    try {
      final userJson = await _secureStorage.read(key: 'auth_user');
      if (userJson == null) return null;
      return AuthUser.fromJson(jsonDecode(userJson));
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeUser(AuthUser user) async {
    await _secureStorage.write(
      key: 'auth_user',
      value: jsonEncode(user.toJson()),
    );
    await _secureStorage.write(key: 'auth_token', value: user.token);
  }

  Future<void> clearUser() async {
    await _secureStorage.delete(key: 'auth_user');
    await _secureStorage.delete(key: 'auth_token');
  }

  Future<SendOtpResponse> sendOtp(String mobileNumber, {String? email}) async {
    return _authApi.sendOtp(SendOtpRequest(
      mobileNumber: mobileNumber,
      email: email,
    ));
  }

  Future<AuthUser?> loginWithOtp(String mobileNumber, String otp,
      {String? email}) async {
    final response = await _authApi.loginWithOtp(LoginWithOtpRequest(
      mobileNumber: mobileNumber,
      otp: otp,
      email: email,
    ));

    if (response.token != null && response.userInfo != null) {
      final user = AuthUser(
        name: response.userInfo!.name,
        email: response.userInfo!.email,
        mobile: response.userInfo!.mobile,
        token: response.token!,
        clientId: extractClientIdFromToken(response.token!) ?? response.userInfo!.clientId.trim(),
      );
      await _storeUser(user);
      return user;
    }
    return null;
  }

  Future<String> signup({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    return _authApi.signup(SignupRequest(
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      password: password,
    ));
  }

  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    return _authApi.forgotPassword(email);
  }

  Future<ResetPasswordResponse> resetPassword(
      String token, String newPassword) async {
    return _authApi.resetPassword(token, newPassword);
  }

  Future<void> logout() async {
    await clearUser();
  }
}

