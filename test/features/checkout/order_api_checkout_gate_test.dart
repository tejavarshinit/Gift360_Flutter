import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/checkout/data/checkout_gate.dart';
import 'package:gift360/features/checkout/data/models/checkout_models.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';
import 'package:gift360/features/order/data/repositories/order_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'payment starts include deviceId in body and never add X-Device-Id',
    () async {
      const installId = '11111111-1111-4111-8111-111111111111';
      SharedPreferences.setMockInitialValues({'g360DeviceId': installId});
      final paymentRequests = <RequestOptions>[];
      final paymentDio = Dio(BaseOptions(baseUrl: 'https://payment.test/api'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              paymentRequests.add(options);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'success': true},
                ),
              );
            },
          ),
        );
      final gate = CheckoutGate(
        api: _OffCheckoutApi(),
        present:
            ({
              required api,
              required requirements,
              required needEmail,
              required needLocation,
            }) async => const CheckoutGateResult.notShown(),
      );
      final orderApi = OrderApi(paymentDio, checkoutGate: gate);

      await orderApi.initiateBackendPayment('ORD-INIT');
      await orderApi.retryPayment(
        'ORD-RETRY',
        walletUsed: true,
        walletAmount: 20,
        earnCashback: false,
      );
      await orderApi.createUpiIntent('ORD-UPI');

      expect(paymentRequests.map((request) => request.path), [
        '/orders/ORD-INIT/initiate-payment',
        '/orders/ORD-RETRY/retry-payment',
        '/orders/ORD-UPI/intent/create',
      ]);
      for (final request in paymentRequests) {
        final body = request.data as Map<String, dynamic>;
        expect(body['deviceId'], installId);
        expect(request.headers.containsKey('X-Device-Id'), isFalse);
        if (request.path.endsWith('/intent/create')) {
          expect(body['paymentMethod'], isNull);
        }
      }
      expect(paymentRequests[0].data['location'], isNull);
      expect(paymentRequests[1].data['walletUsed'], isTrue);
      expect(paymentRequests[2].data['deviceId'], installId);
      paymentDio.close(force: true);
    },
  );

  test('gate cancellation prevents payment endpoint call', () async {
    SharedPreferences.setMockInitialValues({
      'g360DeviceId': '11111111-1111-4111-8111-111111111111',
    });
    var paymentCalls = 0;
    final paymentDio = Dio(BaseOptions(baseUrl: 'https://payment.test/api'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paymentCalls++;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          },
        ),
      );
    final gate = CheckoutGate(
      api: _RequiredCheckoutApi(),
      present:
          ({
            required api,
            required requirements,
            required needEmail,
            required needLocation,
          }) async => const CheckoutGateResult.cancelled(),
    );

    await expectLater(
      OrderApi(
        paymentDio,
        checkoutGate: gate,
      ).initiateBackendPayment('ORD-CANCEL'),
      throwsA(isA<CheckoutCancelledError>()),
    );
    expect(paymentCalls, 0);
    paymentDio.close(force: true);
  });
}

class _OffCheckoutApi implements CheckoutApi {
  @override
  Future<CheckoutRequirements> getRequirements({
    String? orderNumber,
    String? paymentMethod,
  }) async => const CheckoutRequirements(
    email: CheckoutEmailRequirement(
      mode: 'OFF',
      verified: false,
      required: false,
      prompt: false,
    ),
    location: CheckoutLocationRequirement(
      mode: 'OFF',
      ask: false,
      skipped: false,
      required: false,
      maxAgeSeconds: 300,
      pinFallback: false,
      notice: '',
    ),
  );

  @override
  Future<EmailCheckResult> checkEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> confirmEmailCode({required String code}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> sendEmailCode({required String deviceId}) =>
      throw UnimplementedError();
}

class _RequiredCheckoutApi extends _OffCheckoutApi {
  @override
  Future<CheckoutRequirements> getRequirements({
    String? orderNumber,
    String? paymentMethod,
  }) async => const CheckoutRequirements(
    email: CheckoutEmailRequirement(
      mode: 'HARD',
      verified: false,
      required: true,
      prompt: true,
    ),
  );
}
