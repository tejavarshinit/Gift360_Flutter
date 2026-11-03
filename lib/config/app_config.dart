import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get authApiUrl => dotenv.env['AUTH_API_URL'] ?? '';
  static String get brandApiUrl => dotenv.env['BRAND_API_URL'] ?? '';
  static String get cartApiUrl => dotenv.env['CART_API_URL'] ?? '';
  static String get orderApiUrl => dotenv.env['ORDER_API_URL'] ?? '';
  static String get paymentApiUrl => dotenv.env['PAYMENT_API_URL'] ?? '';
  static String get walletApiUrl => dotenv.env['WALLET_API_URL'] ?? '';
  static String get couponApiUrl => dotenv.env['COUPON_API_URL'] ?? '';
  static String get storeApiUrl => dotenv.env['STORE_API_URL'] ?? '';
  static String get supercoinApiUrl => dotenv.env['SUPERCOIN_API_URL'] ?? '';
  static String get giftingApiUrl => dotenv.env['GIFTING_API_URL'] ?? '';
  static String get notificationApiBaseUrl {
    const configuredUrl = String.fromEnvironment('NOTIFICATION_API_URL');
    final url = configuredUrl.trim().isNotEmpty
        ? configuredUrl
        : dotenv.env['NOTIFICATION_API_URL'] ?? '';
    return url.trim().isEmpty ? 'http://localhost:8081' : url.trim();
  }

  static String get firebaseWebVapidKey =>
      dotenv.env['FIREBASE_WEB_VAPID_KEY'] ?? '';
  static FirebaseOptions? get firebaseWebOptions {
    final apiKey = dotenv.env['FIREBASE_WEB_API_KEY']?.trim() ?? '';
    final appId = dotenv.env['FIREBASE_WEB_APP_ID']?.trim() ?? '';
    final messagingSenderId =
        dotenv.env['FIREBASE_MESSAGING_SENDER_ID']?.trim() ?? '';
    final projectId = dotenv.env['FIREBASE_PROJECT_ID']?.trim() ?? '';
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
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'],
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'],
      measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
    );
  }

  /// Notifications/mail service (React `VITE_MAIL_URL`) — voucher emails
  /// (`/mail/send`) are posted straight to it.
  static String get mailApiUrl => dotenv.env['MAIL_URL'] ?? '';
  static String get imageBaseUrl => dotenv.env['IMAGE_BASE_URL'] ?? '';
  static String get encryptionKey => dotenv.env['ENCRYPTION_KEY'] ?? '';
  static String get encryptionIv => dotenv.env['ENCRYPTION_IV'] ?? '';
  static String get sabbpeUserId => dotenv.env['SABBPE_USERID'] ?? '';
  static String get sabbpeMerchantId => dotenv.env['SABBPE_MERCHANTID'] ?? '';
  static String get sabbpePassword => dotenv.env['SABBPE_PASSWORD'] ?? '';
  static String get sabbpeFrontendUrl =>
      dotenv.env['SABBPE_FRONTEND_URL'] ?? '';
  static String get paymentProductInfo =>
      dotenv.env['PAYMENT_PRODUCT_INFO'] ?? 'Gift Voucher Purchase';

  // SabbPe's /initiate API expects the MERCHANT's own registered contact
  // details here, not the end customer's — sending shopper details fails
  // with "Invalid email or phone. Please use your registered account
  // email and phone, not end-user customer details".
  static String get paymentCustFirstName =>
      dotenv.env['PAYMENT_CUSTFIRSTNAME'] ?? 'GIFT360';
  static String get paymentCustEmail =>
      dotenv.env['PAYMENT_CUSTEMAIL'] ?? 'contact@gift360.io';
  static String get paymentCustMobile =>
      dotenv.env['PAYMENT_CUSTMOBILE'] ?? '9876501234';
  static String get supercoinMerchantWalletId =>
      dotenv.env['flipkart.supercoin.walletId'] ?? '';

  /// Cashback wallet redemption — fallback when wallet API doesn't provide values.
  static double get cashbackRedeemPercent {
    final raw = dotenv.env['CASHBACK_REDEEM_PERCENT'];
    return double.tryParse(raw ?? '') ?? 50;
  }

  static double get maxRedeemAmount {
    final raw = dotenv.env['MAX_REDEEM_AMOUNT'];
    return double.tryParse(raw ?? '') ?? 100;
  }

  static double get quizCashbackReward {
    final raw = dotenv.env['QUIZ_CASHBACK_REWARD'];
    return double.tryParse(raw ?? '') ?? 10;
  }

  static int get upiPollIntervalMs {
    final configured = int.tryParse(
      dotenv.env['VITE_UPI_POLL_INTERVAL_MS'] ?? '',
    );
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
    final raw = dotenv.env['SUPERCOIN_BURN_RATIO'];
    return double.tryParse(raw ?? '') ?? 1.0;
  }
}
