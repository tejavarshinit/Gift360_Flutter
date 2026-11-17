/// Which build is running.
///
/// Prod is the default so a normal `lib/main.dart` launch never accepts the
/// dev OTP and never hides UPI. Dev and staging opt in from their own
/// entry points (`lib/main_dev.dart`, `lib/main_staging.dart`).
enum AppFlavor { dev, staging, prod }

class AppFlavorConfig {
  AppFlavorConfig._();

  static AppFlavor flavor = AppFlavor.prod;

  /// Dev login only. Staging and prod never read this.
  static const String devOtp = '1234';

  static void use(AppFlavor value) {
    flavor = value;
  }

  static bool get isDev => flavor == AppFlavor.dev;
  static bool get isStaging => flavor == AppFlavor.staging;
  static bool get isProd => flavor == AppFlavor.prod;

  /// Local login with [devOtp]. No SMS and no auth API.
  static bool get usesMockOtp => isDev;

  /// UPI (Juspay intent, UPI apps, QR) stays off until staging or prod.
  static bool get allowsUpi => !isDev;

  static String get label => switch (flavor) {
    AppFlavor.dev => 'DEV',
    AppFlavor.staging => 'STAGING',
    AppFlavor.prod => 'PROD',
  };
}
