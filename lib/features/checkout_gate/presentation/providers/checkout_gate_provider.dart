import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/checkout_gate/data/repositories/checkout_api.dart';

final checkoutApiProvider = Provider<CheckoutApi>((ref) {
  return CheckoutApi(ref.watch(brandsDioProvider));
});
