class AuthUser {
  final String name;
  final String email;
  final String mobile;
  final String token;
  final String clientId;

  const AuthUser({
    required this.name,
    required this.email,
    required this.mobile,
    required this.token,
    required this.clientId,
  });

  AuthUser copyWith({
    String? name,
    String? email,
    String? mobile,
    String? token,
    String? clientId,
  }) {
    return AuthUser(
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      token: token ?? this.token,
      clientId: clientId ?? this.clientId,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      token: json['token'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'mobile': mobile,
      'token': token,
      'clientId': clientId,
    };
  }
}

class LoginResponse {
  final bool success;
  final String? token;
  final String message;
  final UserInfo? userInfo;

  const LoginResponse({
    this.success = false,
    this.token,
    required this.message,
    this.userInfo,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      token: json['token'] as String?,
      message: json['message'] as String? ?? '',
      userInfo: json['userInfo'] != null
          ? UserInfo.fromJson(json['userInfo'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UserInfo {
  final String name;
  final String email;
  final String mobile;
  final String clientId;

  const UserInfo({
    required this.name,
    required this.email,
    required this.mobile,
    required this.clientId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
    );
  }
}

class SendOtpResponse {
  final bool success;
  final String message;
  final bool? notRegistered;

  const SendOtpResponse({
    required this.success,
    required this.message,
    this.notRegistered,
  });

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      notRegistered: json['notRegistered'] as bool?,
    );
  }
}

class SendOtpRequest {
  final String mobileNumber;
  final String? email;

  const SendOtpRequest({required this.mobileNumber, this.email});

  Map<String, dynamic> toJson() {
    return {
      'mobileNumber': mobileNumber,
      if (email != null) 'email': email,
    };
  }
}

class LoginWithOtpRequest {
  final String mobileNumber;
  final String otp;
  final String? email;

  const LoginWithOtpRequest({
    required this.mobileNumber,
    required this.otp,
    this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'mobileNumber': mobileNumber,
      'otp': otp,
    };
  }
}

class SignupRequest {
  final String name;
  final String email;
  final String mobileNumber;
  final String password;

  const SignupRequest({
    required this.name,
    required this.email,
    required this.mobileNumber,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'mobileNumber': mobileNumber,
      'password': password,
    };
  }
}

class ForgotPasswordRequest {
  final String email;
  const ForgotPasswordRequest({required this.email});
}

class ForgotPasswordResponse {
  final bool success;
  final String message;
  const ForgotPasswordResponse({required this.success, required this.message});

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

class ResetPasswordRequest {
  final String token;
  final String newPassword;
  const ResetPasswordRequest({required this.token, required this.newPassword});
}

class ResetPasswordResponse {
  final bool success;
  final String message;
  const ResetPasswordResponse({required this.success, required this.message});

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}
