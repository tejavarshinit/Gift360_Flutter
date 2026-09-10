import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/coupon/data/repositories/coupon_api.dart';
import 'package:gift360/features/order/data/repositories/order_api.dart';
import 'package:gift360/features/order/data/repositories/validate_order_api.dart';
import 'package:gift360/features/payment/data/models/payment.dart';

final orderApiProvider = Provider<OrderApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return OrderApi(dio);
});

final validateOrderApiProvider = Provider<ValidateOrderApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return ValidateOrderApi(dio);
});

final couponApiProvider = Provider<CouponApi>((ref) {
  final dio = ref.watch(giftcardDioProvider);
  return CouponApi(dio);
});

class PaymentState {
  final bool isLoading;
  final String? error;
  final ValidateOrderResponse? validationResponse;
  final CouponValidateResponse? couponResponse;
  final OrderDetailsResponse? orderDetails;
  final String? orderNumber;
  final String? orderId;
  final String? reservationId;
  final bool orderCreated;
  final bool orderValidated;
  final bool paymentInitiated;
  final String? cartSignature;

  PaymentState({
    this.isLoading = false,
    this.error,
    this.validationResponse,
    this.couponResponse,
    this.orderDetails,
    this.orderNumber,
    this.orderId,
    this.reservationId,
    this.orderCreated = false,
    this.orderValidated = false,
    this.paymentInitiated = false,
    this.cartSignature,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    ValidateOrderResponse? validationResponse,
    CouponValidateResponse? couponResponse,
    OrderDetailsResponse? orderDetails,
    String? orderNumber,
    String? orderId,
    String? reservationId,
    bool? orderCreated,
    bool? orderValidated,
    bool? paymentInitiated,
    String? cartSignature,
    bool clearError = false,
    bool clearValidation = false,
    bool clearCoupon = false,
    bool clearOrderDetails = false,
    bool clearOrder = false,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      validationResponse: clearValidation ? null : (validationResponse ?? this.validationResponse),
      couponResponse: clearCoupon ? null : (couponResponse ?? this.couponResponse),
      orderDetails: clearOrderDetails ? null : (orderDetails ?? this.orderDetails),
      orderNumber: clearOrder ? null : (orderNumber ?? this.orderNumber),
      orderId: clearOrder ? null : (orderId ?? this.orderId),
      reservationId: clearOrder ? null : (reservationId ?? this.reservationId),
      orderCreated: clearOrder ? false : (orderCreated ?? this.orderCreated),
      orderValidated: clearOrder ? false : (orderValidated ?? this.orderValidated),
      paymentInitiated: clearOrder ? false : (paymentInitiated ?? this.paymentInitiated),
      cartSignature: clearOrder ? null : (cartSignature ?? this.cartSignature),
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final OrderApi _orderApi;
  final ValidateOrderApi _validateOrderApi;
  final CouponApi _couponApi;

  PaymentNotifier(this._orderApi, this._validateOrderApi, this._couponApi)
      : super(PaymentState());

  Future<String?> createOrder({
    required String clientId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    bool walletUsed = false,
    double walletAmount = 0,
    double superCoinDeduction = 0,
    double superCoinAmount = 0,
    bool earnCashback = true,
    String? cartSignature,
  }) async {
    // Order reuse (matches React ensureOrder): if an order already exists for
    // the same cart signature, reuse it instead of minting duplicate PENDING
    // orders on every retry.
    if (state.orderNumber != null &&
        state.orderId != null &&
        state.cartSignature != null &&
        cartSignature != null &&
        state.cartSignature == cartSignature) {
      return state.orderNumber;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final now = DateTime.now();
      final yymmdd = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final random = Random.secure();
      final uuid = List.generate(12, (_) => random.nextInt(16).toRadixString(16)).join().toUpperCase();
      final orderNumber = 'ORD$yymmdd$uuid';

      final data = {
        'order': {
          'clientId': clientId,
          'orderNumber': orderNumber,
          'totalAmount': totalAmount,
          'currency': 'INR',
          'status': 'PENDING',
          'walletUsed': walletUsed,
          'walletAmount': walletAmount,
          if (superCoinDeduction > 0) 'superCoinDeduction': superCoinDeduction,
          if (superCoinAmount > 0) 'superCoinAmount': superCoinAmount,
          'earnCashback': earnCashback,
        },
        'items': items,
      };

      final response = await _orderApi.createOrder(data);
      final returnedOrderNumber = response['orderNumber'] as String? ?? orderNumber;
      state = state.copyWith(
        isLoading: false,
        orderCreated: true,
        orderNumber: returnedOrderNumber,
        orderId: response['orderId'] as String?,
        cartSignature: cartSignature,
      );
      return returnedOrderNumber;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> validateOrder({
    required double cartTotal,
    required double walletAmount,
    required bool walletUsed,
  }) async {
    if (state.orderNumber == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _validateOrderApi.validateOrder(
        state.orderNumber!,
        ValidateOrderRequest(
          orderNumber: state.orderNumber!,
          cartTotal: cartTotal,
          walletAmount: walletAmount,
          walletUsed: walletUsed,
        ),
      );
      state = state.copyWith(
        isLoading: false,
        validationResponse: response,
        orderValidated: true,
      );
      return response.valid;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<CouponValidateResponse?> validateCoupon(CouponValidateRequest request) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _couponApi.validateCoupon(request);
      state = state.copyWith(
        isLoading: false,
        couponResponse: response,
        reservationId: response.reservationId,
      );
      // Persist reservationId to survive gateway redirect (matches React sessionStorage)
      if (response.reservationId != null && state.orderNumber != null) {
        await _persistReservation(state.orderNumber!, response.reservationId!);
      }
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> confirmCoupon(String orderId) async {
    final reservationId = state.reservationId;
    if (reservationId == null) return;
    try {
      await _couponApi.confirmCoupon(CouponConfirmRequest(
        reservationId: reservationId,
        orderId: orderId,
      ));
      // Clear persisted reservation after successful confirm
      if (state.orderNumber != null) {
        await _clearReservation(state.orderNumber!);
      }
    } catch (_) {}
  }

  Future<void> releaseCoupon() async {
    final reservationId = state.reservationId;
    if (reservationId == null) return;
    try {
      await _couponApi.releaseCoupon(CouponReleaseRequest(reservationId: reservationId));
      state = state.copyWith(reservationId: null, clearCoupon: true);
      // Clear persisted reservation after release
      if (state.orderNumber != null) {
        await _clearReservation(state.orderNumber!);
      }
    } catch (_) {}
  }

  /// Persist coupon reservation to SharedPreferences (mirrors React's sessionStorage).
  Future<void> _persistReservation(String orderNumber, String reservationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('coupon_reservation_$orderNumber', reservationId);
    } catch (_) {}
  }

  /// Clear persisted coupon reservation from SharedPreferences.
  Future<void> _clearReservation(String orderNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('coupon_reservation_$orderNumber');
    } catch (_) {}
  }

  /// Set flag indicating user just returned from payment (for auto-expand in Orders).
  static Future<void> setJustReturnedFromPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('justReturnedFromPayment', true);
    } catch (_) {}
  }

  /// Check and clear the auto-expand flag (called by Orders screen).
  static Future<bool> consumeJustReturnedFromPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool('justReturnedFromPayment') ?? false;
      if (value) {
        await prefs.remove('justReturnedFromPayment');
      }
      return value;
    } catch (_) {
      return false;
    }
  }

  /// Returns true only if the backend call actually succeeded — callers
  /// must gate coupon/voucher generation on this, exactly like React's
  /// `isUpdateSuccessful` check in PaymentResult.tsx (it deliberately does
  /// NOT call fetchCoupons if the status update itself failed).
  ///
  /// [encryptedOrderRef] MUST be the payment gateway's raw encrypted
  /// `txnid`/`txnId` token (only URL-safe-charset normalized — see
  /// [normalizeEncryptedToken]), sent verbatim as `encryptedData`. The
  /// backend decrypts it server-side to identify the order. Do NOT pass a
  /// decrypted/plain order number here — the backend can't match it, the
  /// status update will silently fail to update the real order, and any
  /// subsequent coupon generation will run against an order still stuck
  /// at PENDING.
  Future<bool> updateOrderStatus(String status, {required String encryptedOrderRef}) async {
    if (encryptedOrderRef.isEmpty) return false;
    try {
      await _orderApi.updateOrderStatus(encryptedOrderRef, status);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> fetchOrderDetails({String? orderNumber}) async {
    final resolvedOrderNumber = orderNumber ?? state.orderNumber;
    if (resolvedOrderNumber == null) return;
    try {
      final data = await _orderApi.fetchOrderDetails(resolvedOrderNumber);
      state = state.copyWith(orderDetails: OrderDetailsResponse.fromJson(data));
    } catch (_) {}
  }

  /// POST /coupons/fetch — this is the call that actually triggers
  /// voucher/coupon **generation** for a PAID order server-side (mirrors
  /// `fetchCouponsMutation` in PaymentResult.tsx). Without this, an order
  /// can be marked PAID but never get its `gift_voucher_item_coupon_details`
  /// populated, so it will show up in the Orders "Vouchers" tab stuck on
  /// "Vouchers are being generated" indefinitely.
  Future<bool> fetchCoupons({required String clientId, required String orderNumber}) async {
    try {
      await _couponApi.fetchCoupons({
        'clientId': clientId,
        'orderNumber': orderNumber,
      });
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void reset() {
    state = PaymentState();
  }

  /// Compute a cart checkout signature (matches React's getCartCheckoutSignature:
  /// sorted "itemId:quantity:unitValue" joined by "|"). Used for order reuse.
  static String cartSignatureFor(List<Map<String, dynamic>> items) {
    final sigs = items
        .map((i) => '${i['brandId']}:${i['quantity']}:${i['unitValue']}')
        .toList()
      ..sort();
    return sigs.join('|');
  }

  /// Reset the in-memory order (e.g. when the cart changes) so a fresh order is
  /// created next time. Mirrors React's useEffect on cart signature change.
  void resetOrder() {
    state = state.copyWith(clearOrder: true);
  }

  /// Backend-mediated payment initiation.
  /// The backend owns the merchant credentials and computes the net payable,
  /// so the frontend never sends an amount or token to the gateway directly.
  /// This is the primary payment flow used in the React reference project.
  /// Uses the giftcards API (matching React's giftcardApiClient).
  Future<Map<String, dynamic>?> initiateBackendPayment() async {
    if (state.orderNumber == null) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _orderApi.initiateBackendPayment(state.orderNumber!);
      state = state.copyWith(
        isLoading: false,
        paymentInitiated: true,
      );
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final orderApi = ref.watch(orderApiProvider);
  final validateOrderApi = ref.watch(validateOrderApiProvider);
  final couponApi = ref.watch(couponApiProvider);
  return PaymentNotifier(orderApi, validateOrderApi, couponApi);
});
