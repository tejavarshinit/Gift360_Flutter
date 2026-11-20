import 'package:flutter/material.dart';

import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/checkout_gate/data/models/checkout_models.dart';
import 'package:gift360/features/checkout_gate/data/repositories/checkout_api.dart';
import 'package:gift360/features/checkout_gate/presentation/widgets/checkout_gate_dialog.dart';
import 'package:gift360/features/profile/data/profile_details_store.dart';

/// Cached location reused for ~4 minutes so retries don't re-prompt.
CheckoutLocation? _cachedLocation;
DateTime? _cachedAt;
const _locationReuse = Duration(minutes: 4);

/// Asks the server what checkout checks are needed, shows the dialog when
/// required, and returns location for the payment POST.
///
/// Fail-open: if requirements call fails → proceed (server still enforces).
Future<CheckoutGateResult> runCheckoutGate({
  required CheckoutApi api,
  required String orderNumber,
  required String paymentMethod,
  AuthUser? user,
  BuildContext? context,
}) async {
  final cached = _readCachedLocation();
  if (cached != null) {
    return CheckoutGateResult.proceeded(cached);
  }

  CheckoutRequirements requirements;
  try {
    requirements = await api.fetchRequirements(
      orderNumber: orderNumber,
      paymentMethod: paymentMethod,
    );
  } catch (e) {
    debugPrint('Checkout requirements failed open: $e');
    return CheckoutGateResult.proceeded();
  }

  if (!requirements.needsDialog) {
    return CheckoutGateResult.proceeded();
  }

  final ctx = context ?? navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) {
    // Can't show UI — fail open; server still enforces.
    return CheckoutGateResult.proceeded();
  }

  String? profileEmail;
  if (user != null) {
    final details = await ProfileDetailsStore.load(user);
    if (!ctx.mounted) return CheckoutGateResult.proceeded();
    profileEmail = details.email.trim().isNotEmpty
        ? details.email.trim()
        : user.email.trim();
  }

  final result = await CheckoutGateDialog.show(
    ctx,
    api: api,
    requirements: requirements,
    profileEmail: profileEmail,
  );

  if (result.location != null) {
    _cachedLocation = result.location;
    _cachedAt = DateTime.now();
  }
  return result;
}

CheckoutLocation? _readCachedLocation() {
  final at = _cachedAt;
  final loc = _cachedLocation;
  if (at == null || loc == null) return null;
  if (DateTime.now().difference(at) > _locationReuse) {
    _cachedLocation = null;
    _cachedAt = null;
    return null;
  }
  return loc;
}

/// Clears the short-lived location cache (e.g. after logout).
void clearCheckoutLocationCache() {
  _cachedLocation = null;
  _cachedAt = null;
}
