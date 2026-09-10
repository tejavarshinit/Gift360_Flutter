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
  bool _initialized = false;

  AuthNotifier(this._secureStorage, this._authApi) : super(null) {
    _loadUser();
  }

  /// True once the persisted session has been fully restored (or confirmed
  /// absent) on cold start. The router waits on this before deciding whether
  /// to redirect a previously-logged-in user to /login — matching React's
  /// synchronous localStorage restore.
  bool get initialized => _initialized;

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
        // Enrich name/email/mobile via validate-token (matches React's
        // fetchValidatedUserInfo) so a restored session shows the real profile.
        user = await _enrichUser(user);
        state = user;
      }
    } catch (e) {
      print('🔐 _loadUser error: $e');
      state = null;
    } finally {
      _initialized = true;
    }
  }

  Future<AuthUser> _enrichUser(AuthUser user) async {
    if (user.token.isEmpty) return user;
    try {
      final data = await _authApi.validateToken();
      final valid = data['valid'] == true;
      final info = data['userInfo'];
      if (valid && info is Map<String, dynamic>) {
        final name = (info['name'] as String?)?.trim().isNotEmpty == true
            ? info['name'].toString()
            : user.name;
        final email = (info['email'] as String?)?.trim().isNotEmpty == true
            ? info['email'].toString()
            : user.email;
        final mobile = (info['mobile'] as String?)?.trim().isNotEmpty == true
            ? info['mobile'].toString()
            : user.mobile;
        final clientId = (info['clientId'] as String?)?.trim().isNotEmpty == true
            ? info['clientId'].toString()
            : user.clientId;
        final enriched = user.copyWith(
          name: name,
          email: email,
          mobile: mobile,
          clientId: clientId,
        );
        _persistUser(enriched);
        return enriched;
      }
    } catch (_) {
      // Best-effort — never break restore on a validate-token failure.
    }
    return user;
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

/// True once the persisted auth session has been restored on cold start.
/// The router must wait for this before redirecting, so previously-logged-in
/// users aren't bounced to /login while the async secure-storage restore runs.
final authInitializedProvider = Provider<bool>((ref) {
  final notifier = ref.watch(authProvider.notifier);
  return notifier.initialized;
});

