import 'package:dio/dio.dart';
import 'package:gift360/core/utils/jwt_utils.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<String> signup(SignupRequest data) async {
    try {
      final response = await _dio.post('/signup', data: data.toJson());
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception(e.response?.data);
      }
      rethrow;
    }
  }

  Future<SendOtpResponse> sendOtp(SendOtpRequest data) async {
    final response = await _dio.post(
      '/login/send-otp',
      data: data.toJson(),
    );
    return SendOtpResponse.fromJson(response.data);
  }

  Future<LoginResponse> loginWithOtp(LoginWithOtpRequest data) async {
    final response = await _dio.post(
      '/login/verify-otp',
      data: data.toJson(),
    );

    final body = response.data;
    final token = body['token'] as String?;

    if (token == null) {
      return LoginResponse(
        success: false,
        token: null,
        message: body['message'] ?? 'Login failed',
        userInfo: null,
      );
    }

    final payload = decodeJwtPayload(token);
    final userInfo = UserInfo(
      name: payload != null ? (payload['name'] ?? '') : '',
      email: payload != null ? (payload['email'] ?? data.email ?? '') : (data.email ?? ''),
      mobile: payload != null ? (payload['phoneNumber'] ?? data.mobileNumber) : data.mobileNumber,
      clientId: extractClientIdFromToken(token) ?? '',
    );

    return LoginResponse(
      success: true,
      token: token,
      message: body['message'] ?? 'Login successful',
      userInfo: userInfo,
    );
  }

  Future<Map<String, dynamic>> login(String emailOrMobile, String password) async {
    final response = await _dio.post('/login', data: {
      'emailOrMobile': emailOrMobile,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    final response = await _dio.post(
      '/forgot-password',
      data: {'email': email},
    );
    return ForgotPasswordResponse.fromJson(response.data);
  }

  Future<Map<String, dynamic>> validateResetToken(String token) async {
    final response = await _dio.post(
      '/forgot-password/validate',
      data: {'token': token},
    );
    return response.data;
  }

  Future<ResetPasswordResponse> resetPassword(
      String token, String newPassword) async {
    final response = await _dio.post(
      '/forgot-password/reset',
      data: {'token': token, 'newPassword': newPassword},
    );
    return ResetPasswordResponse.fromJson(response.data);
  }

  Future<SendOtpResponse> registerSendOtp({
    required String mobileNumber,
    required String email,
  }) async {
    final response = await _dio.post(
      '/register/send-otp',
      data: {'mobileNumber': mobileNumber, 'email': email},
    );
    return SendOtpResponse.fromJson(response.data);
  }

  Future<LoginResponse> registerVerifyOtp({
    required String fullName,
    required String email,
    required String mobileNumber,
    required String otp,
  }) async {
    final response = await _dio.post(
      '/register/verify-otp',
      data: {
        'fullName': fullName,
        'email': email,
        'mobileNumber': mobileNumber,
        'otp': otp,
      },
    );

    final body = response.data;
    final token = body['token'] as String?;

    if (token == null) {
      return LoginResponse(
        success: false,
        token: null,
        message: body['message'] ?? 'Registration failed',
        userInfo: null,
      );
    }

    final userInfo = UserInfo(
      name: fullName,
      email: email,
      mobile: mobileNumber,
      clientId: extractClientIdFromToken(token) ?? '',
    );

    return LoginResponse(
      success: true,
      token: token,
      message: body['message'] ?? 'Registration successful',
      userInfo: userInfo,
    );
  }
}

