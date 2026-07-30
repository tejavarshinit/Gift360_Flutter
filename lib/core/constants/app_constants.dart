class AppConstants {
  AppConstants._();

  static const String appName = 'Gift360';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String authUserKey = 'authUser';
  static const String onboardingKey = 'g360_onboarding_v3';
  static const String cartMergedPrefix = 'cart_merged_';

  // API
  static const int apiTimeout = 30000;
  static const int maxRetries = 3;

  // Pagination
  static const int defaultPageSize = 20;

  // OTP
  static const int otpLength = 6;
  static const int mobileLength = 10;

  // Animation Durations
  static const Duration shortAnim = Duration(milliseconds: 200);
  static const Duration mediumAnim = Duration(milliseconds: 350);
  static const Duration longAnim = Duration(milliseconds: 500);

  // Regex
  static final RegExp mobileRegex = RegExp(r'^[0-9]{10}$');
  static final RegExp otpRegex = RegExp(r'^[0-9]{4,6}$');
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
}
