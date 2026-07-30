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
  static String get imageBaseUrl => dotenv.env['IMAGE_BASE_URL'] ?? '';
  static String get encryptionKey => dotenv.env['ENCRYPTION_KEY'] ?? '';
  static String get encryptionIv => dotenv.env['ENCRYPTION_IV'] ?? '';
  static String get sabbpeUserId => dotenv.env['SABBPE_USERID'] ?? '';
  static String get sabbpeMerchantId => dotenv.env['SABBPE_MERCHANTID'] ?? '';
  static String get sabbpePassword => dotenv.env['SABBPE_PASSWORD'] ?? '';
  static String get sabbpeFrontendUrl => dotenv.env['SABBPE_FRONTEND_URL'] ?? '';
  static String get paymentProductInfo => dotenv.env['PAYMENT_PRODUCT_INFO'] ?? 'Gift Voucher Purchase';

  // SabbPe's /initiate API expects the MERCHANT's own registered contact
  // details here, not the end customer's — sending shopper details fails
  // with "Invalid email or phone. Please use your registered account
  // email and phone, not end-user customer details".
  static String get paymentCustFirstName => dotenv.env['PAYMENT_CUSTFIRSTNAME'] ?? 'GIFT360';
  static String get paymentCustEmail => dotenv.env['PAYMENT_CUSTEMAIL'] ?? 'contact@gift360.io';
  static String get paymentCustMobile => dotenv.env['PAYMENT_CUSTMOBILE'] ?? '9876501234';
  static String get supercoinMerchantWalletId => dotenv.env['SUPERCOIN_MERCHANT_WALLET_ID'] ?? '';

  static const bool enableLogging = true;
}
