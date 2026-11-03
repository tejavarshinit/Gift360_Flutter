import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/gifting/data/repositories/gifting_api.dart';
import 'package:gift360/config/app_config.dart';

final giftingApiProvider = Provider<GiftingApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return GiftingApi(dio);
});

/// Voucher mail service — the notifications backend (`MAIL_URL`) renders the
/// real voucher codes from the DB and emails the registered client (or a
/// gift recipient). Ported from React `hooks/useSendEmail.ts`.
class MailApi {
  final Dio _dio;

  MailApi(this._dio);

  /// POST {MAIL_URL}/mail/send
  Future<void> sendEmail({
    required String clientId,
    required String orderNumber,
    required String templateName,
    String? recipientEmail,
    String? personalMessage,
    String? brandName,
    String? voucherAmount,
  }) async {
    await _dio.post(
      '/mail/send',
      data: {
        'clientId': clientId,
        'orderNumber': orderNumber,
        'templateName': templateName,
        if (recipientEmail != null && recipientEmail.isNotEmpty)
          'recipientEmail': recipientEmail,
        if (personalMessage != null && personalMessage.isNotEmpty)
          'personalMessage': personalMessage,
        if (brandName != null && brandName.isNotEmpty) 'brandName': brandName,
        if (voucherAmount != null && voucherAmount.isNotEmpty)
          'voucherAmount': voucherAmount,
      },
    );
  }
}

final mailApiProvider = Provider<MailApi>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.mailApiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  return MailApi(dio);
});
