import 'package:gift360/features/checkout/data/checkout_gate_logic.dart';
import 'package:gift360/features/checkout/data/models/checkout_models.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';

class CheckoutCancelledError implements Exception {
  const CheckoutCancelledError();

  @override
  String toString() => 'Payment was not started.';
}

class CheckoutGateResult {
  final bool shown;
  final bool cancelled;
  final CheckoutLocation? location;

  const CheckoutGateResult({
    required this.shown,
    this.cancelled = false,
    this.location,
  });

  const CheckoutGateResult.notShown()
    : shown = false,
      cancelled = false,
      location = null;

  const CheckoutGateResult.cancelled()
    : shown = true,
      cancelled = true,
      location = null;

  const CheckoutGateResult.completed({this.location})
    : shown = true,
      cancelled = false;
}

typedef CheckoutGatePresenter =
    Future<CheckoutGateResult> Function({
      required CheckoutApi api,
      required CheckoutRequirements requirements,
      required bool needEmail,
      required bool needLocation,
    });

/// Runs the server-directed gate and remembers an explicitly confirmed
/// location for no longer than four minutes (or the server max-age minus 30s).
class CheckoutGate {
  final CheckoutApi api;
  final CheckoutGatePresenter present;
  final int Function() nowEpochMs;
  CheckoutLocation? _lastLocation;

  CheckoutGate({
    required this.api,
    required this.present,
    int Function()? nowEpochMs,
  }) : nowEpochMs = nowEpochMs ?? _currentEpochMs;

  static int _currentEpochMs() => DateTime.now().millisecondsSinceEpoch;

  Future<CheckoutLocation?> beforePayment({
    required String? orderNumber,
    required String? paymentMethod,
  }) async {
    late final CheckoutRequirements requirements;
    try {
      requirements = await api.getRequirements(
        orderNumber: orderNumber,
        paymentMethod: paymentMethod,
      );
    } catch (_) {
      // Requirements are advisory for the UI. The payment endpoint remains
      // authoritative and performs the same server-side checks.
      return null;
    }

    final needEmail = needsEmailStep(requirements);
    final locationRequirement = requirements.location;
    final reuse = locationRequirement == null
        ? null
        : freshCheckoutLocation(
            location: _lastLocation,
            maxAgeSeconds: locationRequirement.maxAgeSeconds,
            nowEpochMs: nowEpochMs(),
          );
    final needLocation = needsLocationStep(requirements) && reuse == null;

    if (!needEmail && !needLocation) return reuse;

    final result = await present(
      api: api,
      requirements: requirements,
      needEmail: needEmail,
      needLocation: needLocation,
    );
    if (!result.shown) return reuse; // no UI host: fail open; server enforces.
    if (result.cancelled) throw const CheckoutCancelledError();
    if (result.location != null) _lastLocation = result.location;
    return result.location ?? reuse;
  }

  /// Visible for tests and explicit reset when the app session changes.
  void resetLocationReuse() => _lastLocation = null;
}
