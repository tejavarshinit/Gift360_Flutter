import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  // Biometric login entry points (login screen + profile enable/disable).
  static const bool biometricLoginEnabled = true;

  /// Empty when `.env` is missing. The dev flavor is allowed to start that way.
  static String _env(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key]?.trim() ?? '';
  }

  static String get authApiUrl => _env('AUTH_API_URL');
  static String get brandApiUrl => _env('BRAND_API_URL');
  static String get cartApiUrl => _env('CART_API_URL');
  static String get orderApiUrl => _env('ORDER_API_URL');
  static String get paymentApiUrl => _env('PAYMENT_API_URL');
  static String get walletApiUrl => _env('WALLET_API_URL');
  static String get couponApiUrl => _env('COUPON_API_URL');
  static String get storeApiUrl => _env('STORE_API_URL');
  static String get supercoinApiUrl => _env('SUPERCOIN_API_URL');
  static String get giftingApiUrl => _env('GIFTING_API_URL');
  static String get notificationApiBaseUrl {
    const configuredUrl = String.fromEnvironment('NOTIFICATION_API_URL');
    final url = configuredUrl.trim().isNotEmpty
        ? configuredUrl
        : _env('NOTIFICATION_API_URL');
    return url.trim().isEmpty ? brandApiUrl.trim() : url.trim();
  }

  static String get firebaseWebVapidKey => _env('FIREBASE_WEB_VAPID_KEY');
  static FirebaseOptions? get firebaseWebOptions {
    final apiKey = _env('FIREBASE_WEB_API_KEY');
    final appId = _env('FIREBASE_WEB_APP_ID');
    final messagingSenderId = _env('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _env('FIREBASE_PROJECT_ID');
    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: _env('FIREBASE_AUTH_DOMAIN').isEmpty
          ? null
          : _env('FIREBASE_AUTH_DOMAIN'),
      storageBucket: _env('FIREBASE_STORAGE_BUCKET').isEmpty
          ? null
          : _env('FIREBASE_STORAGE_BUCKET'),
      measurementId: _env('FIREBASE_MEASUREMENT_ID').isEmpty
          ? null
          : _env('FIREBASE_MEASUREMENT_ID'),
    );
  }

  /// Notifications/mail service (React `VITE_MAIL_URL`) — voucher emails
  /// (`/mail/send`) are posted straight to it.
  static String get mailApiUrl => _env('MAIL_URL');
  static String get imageBaseUrl => _env('IMAGE_BASE_URL');
  static String get encryptionKey => _env('ENCRYPTION_KEY');
  static String get encryptionIv => _env('ENCRYPTION_IV');
  static String get sabbpeUserId => _env('SABBPE_USERID');
  static String get sabbpeMerchantId => _env('SABBPE_MERCHANTID');
  static String get sabbpePassword => _env('SABBPE_PASSWORD');
  static String get sabbpeFrontendUrl => _env('SABBPE_FRONTEND_URL');
  static String get paymentProductInfo {
    final value = _env('PAYMENT_PRODUCT_INFO');
    return value.isEmpty ? 'Gift Voucher Purchase' : value;
  }

  // SabbPe's /initiate API expects the MERCHANT's own registered contact
  // details here, not the end customer's — sending shopper details fails
  // with "Invalid email or phone. Please use your registered account
  // email and phone, not end-user customer details".
  static String get paymentCustFirstName {
    final value = _env('PAYMENT_CUSTFIRSTNAME');
    return value.isEmpty ? 'GIFT360' : value;
  }

  static String get paymentCustEmail {
    final value = _env('PAYMENT_CUSTEMAIL');
    return value.isEmpty ? 'contact@gift360.io' : value;
  }

  static String get paymentCustMobile {
    final value = _env('PAYMENT_CUSTMOBILE');
    return value.isEmpty ? '9876501234' : value;
  }

  static String get supercoinMerchantWalletId =>
      _env('flipkart.supercoin.walletId');

  /// Cashback wallet redemption — fallback when wallet API doesn't provide values.
  static double get cashbackRedeemPercent {
    return double.tryParse(_env('CASHBACK_REDEEM_PERCENT')) ?? 50;
  }

  static double get maxRedeemAmount {
    return double.tryParse(_env('MAX_REDEEM_AMOUNT')) ?? 100;
  }

  static double get quizCashbackReward {
    return double.tryParse(_env('QUIZ_CASHBACK_REWARD')) ?? 10;
  }

  static int get upiPollIntervalMs {
    final configured = int.tryParse(_env('VITE_UPI_POLL_INTERVAL_MS'));
    return configured == null || configured < 500 ? 2000 : configured;
  }

  static const bool enableLogging = true;
}

/// SuperCoin conversion feature flags, matching React's features.config.ts.
class SuperCoinConversionConfig {
  SuperCoinConversionConfig._();

  /// Kill switch — when paused, every SuperCoin entry point shows a toast
  /// and blocks instead of proceeding.
  static bool get paused =>
      const bool.fromEnvironment('SUPERCOIN_PAUSED', defaultValue: false);

  static String get pausedMessage => const String.fromEnvironment(
    'SUPERCOIN_PAUSED_MESSAGE',
    defaultValue:
        'SuperCoin conversion is temporarily paused. Please try again later.',
  );

  /// Flipkart B2C brand id pre-selected when the header icon is tapped.
  /// Matches React's SUPERCOIN_FEATURED_BRAND_ID in SuperCoinsBrandModal.tsx.
  static const String featuredBrandId = 'c1ae829e-0e78-4dfe-8432-c4c1ac9360e1';

  /// SKU whose SuperCoin rules drive the convert flow (matches React's
  /// VITE_SUPERCOIN_VOUCHER_SKU default).
  static const String voucherSku = 'EGCGBFKC002';

  /// Rupee → coin conversion ratio (default 1.00, matches React's VITE_SUPERCOIN_BURN_RATIO).
  /// Reads from .env at runtime so changing the ratio doesn't require rebuild.
  static double get burnRatio {
    if (!dotenv.isInitialized) return 1.0;
    return double.tryParse(dotenv.env['SUPERCOIN_BURN_RATIO'] ?? '') ?? 1.0;
  }
}
