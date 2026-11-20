import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/checkout/data/checkout_gate.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';
import 'package:gift360/features/checkout/presentation/widgets/checkout_gate_sheet.dart';

final checkoutApiProvider = Provider<CheckoutApi>((ref) {
  // Checkout rules and email verification live under the ValueDesign /api base,
  // not the /api/v1/giftcards payment base.
  return CheckoutApi(ref.watch(brandsDioProvider));
});

final checkoutGateProvider = Provider<CheckoutGate>((ref) {
  return CheckoutGate(
    api: ref.watch(checkoutApiProvider),
    present: presentCheckoutGate,
  );
});
