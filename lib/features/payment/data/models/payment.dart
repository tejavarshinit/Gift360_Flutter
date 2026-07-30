class TokenGenerationResponse {
  final bool status;
  final String? sabbpeToken;
  final String? transactionId;
  final String? message;

  TokenGenerationResponse({
    required this.status,
    this.sabbpeToken,
    this.transactionId,
    this.message,
  });

  factory TokenGenerationResponse.fromJson(Map<String, dynamic> json) {
    return TokenGenerationResponse(
      status: json['status'] == true || json['status'] == 1,
      sabbpeToken: json['sabbpe_token'] as String?,
      transactionId: json['transaction_id'] as String?,
      message: json['message'] as String?,
    );
  }
}

class SabbPeInitiateRequest {
  final String sabbpeToken;
  final String productInfo;
  final double amount;
  final String frontendUrl;
  final String? encryptedOrderRef;
  final String? clientId;
  final CustomerInfo customer;

  SabbPeInitiateRequest({
    required this.sabbpeToken,
    required this.productInfo,
    required this.amount,
    required this.frontendUrl,
    this.encryptedOrderRef,
    this.clientId,
    required this.customer,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sabbpe_token': sabbpeToken,
      'productinfo': productInfo,
      'amount': amount,
      'frontend_url': frontendUrl,
      'customer': customer.toJson(),
    };
    if (encryptedOrderRef != null) map['encrypted_order_ref'] = encryptedOrderRef;
    if (clientId != null) map['client_id'] = clientId;
    return map;
  }
}

class CustomerInfo {
  final String firstname;
  final String email;
  final String phone;

  CustomerInfo({
    required this.firstname,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
    'firstname': firstname,
    'email': email,
    'phone': phone,
  };
}

class SabbPeInitiateResponse {
  final bool status;
  final String? paymentUrl;
  final String? transactionId;
  final String? merchantOrderRef;
  final String? gateway;
  final String? message;
  final String? data;

  SabbPeInitiateResponse({
    required this.status,
    this.paymentUrl,
    this.transactionId,
    this.merchantOrderRef,
    this.gateway,
    this.message,
    this.data,
  });

  factory SabbPeInitiateResponse.fromJson(Map<String, dynamic> json) {
    return SabbPeInitiateResponse(
      status: json['status'] == true || json['status'] == 1,
      paymentUrl: json['payment_url'] as String? ?? json['paymentUrl'] as String? ?? json['data'] as String?,
      transactionId: json['transactionId'] as String? ?? json['txnid'] as String?,
      merchantOrderRef: json['merchantOrderRef'] as String?,
      gateway: json['gateway'] as String?,
      message: json['message'] as String?,
      data: json['data'] as String?,
    );
  }
}

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

  Map<String, dynamic> toJson() => {
    'reservationId': reservationId,
  };
}

class OrderDetailsResponse {
  final String? orderNumber;
  final String? status;
  final int? coinsEarned;
  final String? createdAt;
  final List<OrderItemDetail>? items;

  OrderDetailsResponse({
    this.orderNumber,
    this.status,
    this.coinsEarned,
    this.createdAt,
    this.items,
  });

  factory OrderDetailsResponse.fromJson(Map<String, dynamic> json) {
    return OrderDetailsResponse(
      orderNumber: json['order_number'] as String?,
      status: json['status'] as String?,
      coinsEarned: json['coins_earned'] as int?,
      createdAt: json['created_at'] as String?,
      items: (json['items'] as List?)?.map((i) => OrderItemDetail.fromJson(i as Map<String, dynamic>)).toList(),
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
      brandName: json['brand_name'] as String? ?? json['meta']?['brand_name'] as String?,
      unitValue: (json['unitValue'] as num?)?.toDouble(),
      quantity: json['quantity'] as int?,
    );
  }
}
