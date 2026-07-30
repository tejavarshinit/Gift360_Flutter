import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/coupon/data/repositories/coupon_api.dart';
import 'package:gift360/features/order/data/repositories/order_api.dart';
import 'package:gift360/features/order/data/repositories/validate_order_api.dart';
import 'package:gift360/features/payment/data/models/payment.dart';
import 'package:gift360/features/payment/data/repositories/payment_api.dart';

final paymentApiProvider = Provider<PaymentApi>((ref) {
  final dio = ref.watch(paymentDioProvider);
  return PaymentApi(dio);
});

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
  final TokenGenerationResponse? tokenResponse;
  final SabbPeInitiateResponse? initiateResponse;
  final ValidateOrderResponse? validationResponse;
  final CouponValidateResponse? couponResponse;
  final OrderDetailsResponse? orderDetails;
  final String? orderNumber;
  final String? orderId;
  final String? reservationId;
  final bool orderCreated;
  final bool orderValidated;
  final bool paymentInitiated;

  PaymentState({
    this.isLoading = false,
    this.error,
    this.tokenResponse,
    this.initiateResponse,
    this.validationResponse,
    this.couponResponse,
    this.orderDetails,
    this.orderNumber,
    this.orderId,
    this.reservationId,
    this.orderCreated = false,
    this.orderValidated = false,
    this.paymentInitiated = false,
  });

  PaymentState copyWith({
    bool? isLoading,
    String? error,
    TokenGenerationResponse? tokenResponse,
    SabbPeInitiateResponse? initiateResponse,
    ValidateOrderResponse? validationResponse,
    CouponValidateResponse? couponResponse,
    OrderDetailsResponse? orderDetails,
    String? orderNumber,
    String? orderId,
    String? reservationId,
    bool? orderCreated,
    bool? orderValidated,
    bool? paymentInitiated,
    bool clearError = false,
    bool clearToken = false,
    bool clearInitiate = false,
    bool clearValidation = false,
    bool clearCoupon = false,
    bool clearOrderDetails = false,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      tokenResponse: clearToken ? null : (tokenResponse ?? this.tokenResponse),
      initiateResponse: clearInitiate ? null : (initiateResponse ?? this.initiateResponse),
      validationResponse: clearValidation ? null : (validationResponse ?? this.validationResponse),
      couponResponse: clearCoupon ? null : (couponResponse ?? this.couponResponse),
      orderDetails: clearOrderDetails ? null : (orderDetails ?? this.orderDetails),
      orderNumber: orderNumber ?? this.orderNumber,
      orderId: orderId ?? this.orderId,
      reservationId: reservationId ?? this.reservationId,
      orderCreated: orderCreated ?? this.orderCreated,
      orderValidated: orderValidated ?? this.orderValidated,
      paymentInitiated: paymentInitiated ?? this.paymentInitiated,
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentApi _paymentApi;
  final OrderApi _orderApi;
  final ValidateOrderApi _validateOrderApi;
  final CouponApi _couponApi;

  PaymentNotifier(this._paymentApi, this._orderApi, this._validateOrderApi, this._couponApi)
      : super(PaymentState());

  Future<String?> createOrder({
    required String clientId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    bool walletUsed = false,
    double walletAmount = 0,
  }) async {
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

  Future<bool> generateToken() async {
    if (state.orderNumber == null) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _paymentApi.generateToken(state.orderNumber!);
      state = state.copyWith(
        isLoading: false,
        tokenResponse: response,
      );
      return response.sabbpeToken != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> initiatePayment({
    required double amount,
    required String productInfo,
    required String frontendUrl,
    required CustomerInfo customer,
    String? encryptedOrderRef,
    String? clientId,
  }) async {
    final token = state.tokenResponse?.sabbpeToken;
    if (token == null) {
      state = state.copyWith(error: 'No payment token available');
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _paymentApi.initiatePayment(SabbPeInitiateRequest(
        sabbpeToken: token,
        productInfo: productInfo,
        amount: amount,
        frontendUrl: frontendUrl,
        encryptedOrderRef: encryptedOrderRef,
        clientId: clientId,
        customer: customer,
      ));
      state = state.copyWith(
        isLoading: false,
        initiateResponse: response,
        paymentInitiated: true,
      );
      return response.status;
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
    } catch (_) {}
  }

  Future<void> releaseCoupon() async {
    final reservationId = state.reservationId;
    if (reservationId == null) return;
    try {
      await _couponApi.releaseCoupon(CouponReleaseRequest(reservationId: reservationId));
      state = state.copyWith(reservationId: null, clearCoupon: true);
    } catch (_) {}
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
}

final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  final paymentApi = ref.watch(paymentApiProvider);
  final orderApi = ref.watch(orderApiProvider);
  final validateOrderApi = ref.watch(validateOrderApiProvider);
  final couponApi = ref.watch(couponApiProvider);
  return PaymentNotifier(paymentApi, orderApi, validateOrderApi, couponApi);
});
