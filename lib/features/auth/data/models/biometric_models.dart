class BiometricEnrollment {
  final String deviceId;
  final String clientId;

  const BiometricEnrollment({required this.deviceId, required this.clientId});
}

class BiometricAvailability {
  final bool supported;
  final bool enrolled;
  final String? reason;

  const BiometricAvailability({
    required this.supported,
    required this.enrolled,
    this.reason,
  });
}

class BiometricLoginResult {
  final String token;
  final String clientId;
  final String name;
  final String email;
  final String mobile;

  const BiometricLoginResult({
    required this.token,
    required this.clientId,
    required this.name,
    required this.email,
    required this.mobile,
  });
}

class BiometricException implements Exception {
  final String message;

  const BiometricException(this.message);

  @override
  String toString() => message;
}

class BiometricEnrollmentState {
  final BiometricEnrollment? enrollment;
  final String? issue;

  const BiometricEnrollmentState({this.enrollment, this.issue});

  bool get isEnabled => enrollment != null && issue == null;
}
