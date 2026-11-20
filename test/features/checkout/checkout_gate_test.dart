import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/core/network/dio_client.dart'
    show checkoutLocationErrorMessage;
import 'package:gift360/core/utils/checkout_device_id.dart';
import 'package:gift360/features/checkout/data/checkout_gate.dart';
import 'package:gift360/features/checkout/data/checkout_gate_logic.dart';
import 'package:gift360/features/checkout/data/models/checkout_models.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';
import 'package:gift360/features/checkout/presentation/widgets/checkout_gate_sheet.dart';

void main() {
  group('checkout gate decisions', () {
    test('requirements select email and location independently', () {
      final requirements = CheckoutRequirements(
        email: const CheckoutEmailRequirement(
          mode: 'SOFT',
          verified: false,
          required: false,
          prompt: true,
        ),
        location: const CheckoutLocationRequirement(
          mode: 'COLLECT',
          ask: true,
          skipped: false,
          required: false,
          maxAgeSeconds: 300,
          pinFallback: true,
          notice: 'Share location for payment.',
        ),
      );

      expect(needsEmailStep(requirements), isTrue);
      expect(needsLocationStep(requirements), isTrue);
    });

    test('verified, unprompted and unasked requirements need no screen', () {
      final requirements = CheckoutRequirements(
        email: const CheckoutEmailRequirement(
          mode: 'HARD',
          verified: true,
          required: false,
          prompt: false,
        ),
        location: const CheckoutLocationRequirement(
          mode: 'ENFORCE',
          ask: false,
          skipped: true,
          required: false,
          maxAgeSeconds: 300,
          pinFallback: true,
          notice: '',
        ),
      );

      expect(needsEmailStep(requirements), isFalse);
      expect(needsLocationStep(requirements), isFalse);
    });

    test('dismissing the sheet always cancels the payment start', () {
      expect(checkoutGateResultFromSheet(null).cancelled, isTrue);
      expect(
        checkoutGateResultFromSheet(
          const CheckoutGateResult.completed(),
        ).cancelled,
        isFalse,
      );
    });

    test('reuses only confirmed locations younger than four minutes', () {
      final location = CheckoutLocation.pin(
        pincode: '560102',
        capturedAt: 1000000,
      );
      expect(
        freshCheckoutLocation(
          location: location,
          maxAgeSeconds: 300,
          nowEpochMs: 1000000 + const Duration(minutes: 3).inMilliseconds,
        ),
        same(location),
      );
      expect(
        freshCheckoutLocation(
          location: location,
          maxAgeSeconds: 300,
          nowEpochMs: 1000000 + const Duration(minutes: 4).inMilliseconds,
        ),
        isNull,
      );
      expect(
        freshCheckoutLocation(
          location: location,
          maxAgeSeconds: 60,
          nowEpochMs: 1000000 + const Duration(seconds: 31).inMilliseconds,
        ),
        isNull,
      );
    });

    test('fails open when requirements endpoint fails', () async {
      var presenterCalls = 0;
      final gate = CheckoutGate(
        api: _FakeCheckoutApi(error: StateError('network')),
        present:
            ({
              required api,
              required requirements,
              required needEmail,
              required needLocation,
            }) async {
              presenterCalls++;
              return const CheckoutGateResult.cancelled();
            },
      );

      expect(
        await gate.beforePayment(orderNumber: 'ORD1', paymentMethod: 'UPI'),
        isNull,
      );
      expect(presenterCalls, 0);
    });

    test(
      'all flags off shows no UI; both requested steps are passed together',
      () async {
        final off = _FakeCheckoutApi(
          requirements: const CheckoutRequirements(
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
          ),
        );
        var presenterCalls = 0;
        final offGate = CheckoutGate(
          api: off,
          present:
              ({
                required api,
                required requirements,
                required needEmail,
                required needLocation,
              }) async {
                presenterCalls++;
                return const CheckoutGateResult.notShown();
              },
        );
        expect(
          await offGate.beforePayment(orderNumber: 'ORD2', paymentMethod: null),
          isNull,
        );
        expect(presenterCalls, 0);

        final both = _FakeCheckoutApi(
          requirements: const CheckoutRequirements(
            email: CheckoutEmailRequirement(
              mode: 'SOFT',
              verified: false,
              required: false,
              prompt: true,
            ),
            location: CheckoutLocationRequirement(
              mode: 'COLLECT',
              ask: true,
              skipped: false,
              required: false,
              maxAgeSeconds: 300,
              pinFallback: true,
              notice: 'notice',
            ),
          ),
        );
        var sawEmail = false;
        var sawLocation = false;
        final bothGate = CheckoutGate(
          api: both,
          present:
              ({
                required api,
                required requirements,
                required needEmail,
                required needLocation,
              }) async {
                sawEmail = needEmail;
                sawLocation = needLocation;
                return const CheckoutGateResult.completed();
              },
        );
        await bothGate.beforePayment(
          orderNumber: 'ORD3',
          paymentMethod: 'CARD',
        );
        expect(sawEmail, isTrue);
        expect(sawLocation, isTrue);
      },
    );

    test('confirmed location is reused without reopening the gate', () async {
      var now = 5000000;
      final api = _FakeCheckoutApi(
        requirements: const CheckoutRequirements(
          email: CheckoutEmailRequirement(
            mode: 'OFF',
            verified: true,
            required: false,
            prompt: false,
          ),
          location: CheckoutLocationRequirement(
            mode: 'COLLECT',
            ask: true,
            skipped: false,
            required: false,
            maxAgeSeconds: 300,
            pinFallback: true,
            notice: 'Share location.',
          ),
        ),
      );
      var presenterCalls = 0;
      final location = CheckoutLocation.pin(pincode: '560102', capturedAt: now);
      final gate = CheckoutGate(
        api: api,
        nowEpochMs: () => now,
        present:
            ({
              required api,
              required requirements,
              required needEmail,
              required needLocation,
            }) async {
              presenterCalls++;
              return CheckoutGateResult.completed(location: location);
            },
      );

      expect(
        await gate.beforePayment(orderNumber: 'ORD4', paymentMethod: 'UPI'),
        same(location),
      );
      now += const Duration(minutes: 3, seconds: 59).inMilliseconds;
      expect(
        await gate.beforePayment(orderNumber: 'ORD5', paymentMethod: 'UPI'),
        same(location),
      );
      expect(presenterCalls, 1);
    });

    test('cancelling a required gate prevents payment continuation', () async {
      final gate = CheckoutGate(
        api: _FakeCheckoutApi(
          requirements: const CheckoutRequirements(
            email: CheckoutEmailRequirement(
              mode: 'HARD',
              verified: false,
              required: true,
              prompt: true,
            ),
          ),
        ),
        present:
            ({
              required api,
              required requirements,
              required needEmail,
              required needLocation,
            }) async => const CheckoutGateResult.cancelled(),
      );
      await expectLater(
        gate.beforePayment(orderNumber: 'ORD6', paymentMethod: null),
        throwsA(isA<CheckoutCancelledError>()),
      );
    });
  });

  group('email result messages', () {
    test('covers send statuses and retry delay', () {
      expect(emailSendStatusMessage('SENT'), isNull);
      expect(emailSendStatusMessage('ALREADY_VERIFIED'), isNull);
      expect(emailSendStatusMessage('DISABLED'), isNull);
      expect(
        emailSendStatusMessage('RATE_LIMITED'),
        'Too many codes requested. Try again in an hour.',
      );
      expect(
        emailSendStatusMessage('LOCKED', retryAfterSeconds: 90),
        'Too many wrong codes. Try again in 2 minutes.',
      );
      expect(
        emailSendStatusMessage('SEND_FAILED'),
        "We couldn't send the code just now. Please try again.",
      );
      expect(emailSendStatusMessage('NO_EMAIL'), contains('Profile'));
      expect(emailSendStatusMessage('INVALID_EMAIL'), contains('Profile'));
      expect(emailSendStatusMessage('IN_USE'), contains('Profile'));
    });

    test('covers confirm statuses and attempts remaining', () {
      expect(emailConfirmStatusMessage('VERIFIED'), isNull);
      expect(emailConfirmStatusMessage('ALREADY_VERIFIED'), isNull);
      expect(emailConfirmStatusMessage('DISABLED'), isNull);
      expect(
        emailConfirmStatusMessage('WRONG_CODE', attemptsLeft: 2),
        'That code is not right. 2 tries left.',
      );
      expect(
        emailConfirmStatusMessage('EXPIRED'),
        'That code has expired. Send a new one.',
      );
      expect(
        emailConfirmStatusMessage('LOCKED', retryAfterSeconds: 60),
        'Too many wrong codes. Try again in 1 minute.',
      );
      expect(emailConfirmStatusMessage('NO_CODE'), 'Please send a code first.');
      expect(emailConfirmStatusMessage('NO_EMAIL'), contains('Profile'));
    });
  });

  group('location payloads', () {
    test('GPS includes location metadata and consent', () {
      final payload = CheckoutLocation.gps(
        latitude: 12.9,
        longitude: 77.6,
        accuracyMeters: 8.5,
        capturedAt: 123456,
        pincode: '560102',
        city: 'Bengaluru',
        state: 'Karnataka',
      ).toJson();
      expect(payload, {
        'source': 'GPS',
        'latitude': 12.9,
        'longitude': 77.6,
        'accuracyMeters': 8.5,
        'capturedAt': 123456,
        'pincode': '560102',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'consent': true,
      });
    });

    test('PIN payload has no coordinates', () {
      final payload = CheckoutLocation.pin(
        pincode: '560102',
        capturedAt: 987654,
      ).toJson();
      expect(payload, {
        'source': 'PIN',
        'capturedAt': 987654,
        'pincode': '560102',
        'consent': true,
      });
      expect(payload.containsKey('latitude'), isFalse);
      expect(payload.containsKey('longitude'), isFalse);
    });
  });

  group('server LOCATION_* error codes map to user copy', () {
    test('known reasons get specific messages', () {
      expect(
        checkoutLocationErrorMessage('LOCATION_MISSING'),
        'Please share your location or enter your PIN code to continue.',
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_STALE'),
        'Your location confirmation expired. Please confirm it again.',
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_OUTSIDE_INDIA'),
        contains('outside India'),
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_PIN_INVALID'),
        contains('6-digit postal PIN'),
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_PIN_NOT_ALLOWED'),
        contains("can't be used"),
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_CONSENT_MISSING'),
        'Please agree to share your location for this payment.',
      );
      expect(
        checkoutLocationErrorMessage('LOCATION_UNKNOWN'),
        'Please share your location or enter your PIN code to continue.',
      );
    });
  });

  test('device id is a persisted random UUIDv4', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await getCheckoutDeviceId();
    final second = await getCheckoutDeviceId();
    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, first);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('g360DeviceId'), first);
  });
}

class _FakeCheckoutApi implements CheckoutApi {
  final CheckoutRequirements? requirements;
  final Object? error;

  const _FakeCheckoutApi({this.requirements, this.error});

  @override
  Future<CheckoutRequirements> getRequirements({
    String? orderNumber,
    String? paymentMethod,
  }) async {
    if (error != null) throw error!;
    return requirements ?? const CheckoutRequirements();
  }

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
