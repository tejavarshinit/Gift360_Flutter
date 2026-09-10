class ValidateOrderRequest {
  final String orderNumber;
  final double cartTotal;
  final double walletAmount;
  final bool walletUsed;

  ValidateOrderRequest({
    required this.orderNumber,
    required this.cartTotal,
    required this.walletAmount,
    required this.walletUsed,
  });

  Map<String, dynamic> toJson() => {
    'cartTotal': cartTotal,
    'walletAmount': walletAmount,
    'walletUsed': walletUsed,
  };
}

class ValidateOrderResponse {
  final bool valid;
  final double amountToPay;
  final String? message;

  ValidateOrderResponse({
    required this.valid,
    required this.amountToPay,
    this.message,
  });

  factory ValidateOrderResponse.fromJson(Map<String, dynamic> json) {
    return ValidateOrderResponse(
      valid: json['valid'] == true,
      amountToPay: (json['amountToPay'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String?,
    );
  }
}

class CouponValidateRequest {
  final String couponCode;
  final String orderId;
  final String clientId;
  final List<CouponItem> items;
  final double subtotal;
  final double fee;
  final String? employeeId;
  final String? corporateId;

  CouponValidateRequest({
    required this.couponCode,
    required this.orderId,
    required this.clientId,
    required this.items,
    required this.subtotal,
    required this.fee,
    this.employeeId,
    this.corporateId,
  });

  Map<String, dynamic> toJson() => {
    'couponCode': couponCode,
    'orderId': orderId,
    'clientId': clientId,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'fee': fee,
    'employeeId': employeeId,
    'corporateId': corporateId,
    'context': null,
  };
}

class CouponItem {
  final String brandName;
  final int quantity;
  final double unitValue;

  CouponItem({
    required this.brandName,
    required this.quantity,
    required this.unitValue,
  });

  Map<String, dynamic> toJson() => {
    'brandName': brandName,
    'quantity': quantity,
    'unitValue': unitValue,
  };
}

class CouponValidateResponse {
  final int? httpStatus;
  final String? message;
  final String? httpMessage;
  final String? reservationId;
  final String? couponId;
  final double discount;
  final double finalAmount;

  CouponValidateResponse({
    this.httpStatus,
    this.message,
    this.httpMessage,
    this.reservationId,
    this.couponId,
    this.discount = 0,
    this.finalAmount = 0,
  });

  factory CouponValidateResponse.fromJson(Map<String, dynamic> json) {
    final discountRaw = json['discount'];
    double discountValue = 0;
    if (discountRaw is String) {
      discountValue = double.tryParse(discountRaw) ?? 0;
    } else if (discountRaw is num) {
      discountValue = discountRaw.toDouble();
    } else if (discountRaw is Map) {
      discountValue = (discountRaw['value'] as num?)?.toDouble() ?? 0;
    }

    return CouponValidateResponse(
      httpStatus: json['httpStatus'] as int?,
      message: json['message'] as String?,
      httpMessage: json['httpMessage'] as String?,
      reservationId: json['reservation_id'] as String?,
      couponId: json['coupon_id']?.toString(),
      discount: discountValue,
      finalAmount: (json['final_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CouponConfirmRequest {
  final String reservationId;
  final String orderId;

  CouponConfirmRequest({required this.reservationId, required this.orderId});

  Map<String, dynamic> toJson() => {
    'reservationId': reservationId,
    'orderId': orderId,
  };
}

class CouponReleaseRequest {
  final String reservationId;

  CouponReleaseRequest({required this.reservationId});

  Map<String, dynamic> toJson() => {'reservationId': reservationId};
}

class OrderDetailsResponse {
  final String? orderNumber;
  final String? status;
  final int? coinsEarned;
  final double? cashbackEarned;
  final String? createdAt;
  final List<OrderItemDetail>? items;

  OrderDetailsResponse({
    this.orderNumber,
    this.status,
    this.coinsEarned,
    this.cashbackEarned,
    this.createdAt,
    this.items,
  });

  factory OrderDetailsResponse.fromJson(Map<String, dynamic> json) {
    return OrderDetailsResponse(
      orderNumber: json['order_number'] as String?,
      status: json['status'] as String?,
      coinsEarned: json['coins_earned'] as int?,
      cashbackEarned: (json['cashback_earned'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String?,
      items: (json['items'] as List?)
          ?.map((i) => OrderItemDetail.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderItemDetail {
  final String? brandName;
  final double? unitValue;
  final int? quantity;

  OrderItemDetail({this.brandName, this.unitValue, this.quantity});

  factory OrderItemDetail.fromJson(Map<String, dynamic> json) {
    return OrderItemDetail(
      brandName:
          json['brand_name'] as String? ??
          json['meta']?['brand_name'] as String?,
      unitValue: (json['unitValue'] as num?)?.toDouble(),
      quantity: json['quantity'] as int?,
    );
  }
}
