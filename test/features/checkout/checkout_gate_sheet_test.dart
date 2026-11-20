import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/checkout/data/models/checkout_models.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';
import 'package:gift360/features/checkout/presentation/widgets/checkout_gate_sheet.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const emailRequirement = CheckoutEmailRequirement(
    mode: 'SOFT',
    verified: false,
    required: false,
    prompt: true,
    maskedEmail: 'te***@mail.com',
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required CheckoutRequirements requirements,
    required bool needEmail,
    required bool needLocation,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckoutGateSheet(
            api: _FakeCheckoutApi(),
            requirements: requirements,
            needEmail: needEmail,
            needLocation: needLocation,
          ),
        ),
      ),
    );
  }

  group('email step is mandatory in every mode', () {
    for (final mode in ['OFF', 'LOG', 'SOFT', 'HARD']) {
      for (final required in [true, false]) {
        testWidgets('$mode required=$required has no Skip for now', (
          tester,
        ) async {
          await pumpSheet(
            tester,
            requirements: CheckoutRequirements(
              email: CheckoutEmailRequirement(
                mode: mode,
                verified: false,
                required: required,
                prompt: true,
                maskedEmail: 'te***@mail.com',
              ),
            ),
            needEmail: true,
            needLocation: false,
          );

          expect(find.text('Skip for now'), findsNothing);
          expect(find.textContaining('Skip'), findsNothing);
        });
      }
    }

    testWidgets('uses the mandatory verification copy', (tester) async {
      await pumpSheet(
        tester,
        requirements: const CheckoutRequirements(email: emailRequirement),
        needEmail: true,
        needLocation: false,
      );

      expect(
        find.text(
          'This is being asked to send vouchers for your registered email ID for security purposes.',
        ),
        findsOneWidget,
      );
    });
  });

  group('location step is mandatory in every mode', () {
    for (final required in [true, false]) {
      testWidgets('required=$required has no Skip action', (tester) async {
        await pumpSheet(
          tester,
          requirements: CheckoutRequirements(
            email: emailRequirement,
            location: CheckoutLocationRequirement(
              mode: required ? 'ENFORCE' : 'COLLECT',
              ask: true,
              skipped: false,
              required: required,
              maxAgeSeconds: 300,
              pinFallback: true,
              notice:
                  'Location is required to ensure that your transactions are safe.',
            ),
          ),
          needEmail: false,
          needLocation: true,
        );

        expect(find.text('Skip'), findsNothing);
        expect(find.textContaining('Skip'), findsNothing);
        expect(
          find.text(
            'Location is required to ensure that your transactions are safe.',
          ),
          findsOneWidget,
        );
        // Simplified location step: no "Use my location instead" action, and
        // the PIN shortcut only exists on the initial chooser.
        expect(find.text('Use my location instead'), findsNothing);
        expect(find.text('Enter PIN code instead'), findsOneWidget);
      });
    }
  });
}

class _FakeCheckoutApi implements CheckoutApi {
  @override
  Future<CheckoutRequirements> getRequirements({
    String? orderNumber,
    String? paymentMethod,
  }) async => const CheckoutRequirements();

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
