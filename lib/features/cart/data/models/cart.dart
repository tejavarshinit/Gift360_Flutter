class CartItem {
  final String itemId;
  final String brandId;
  final String brandName;
  final int quantity;
  final double unitValue;
  final double lineTotal;
  final String? image;
  final double? discount;

  const CartItem({
    required this.itemId,
    required this.brandId,
    required this.brandName,
    required this.quantity,
    required this.unitValue,
    required this.lineTotal,
    this.image,
    this.discount,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      itemId: json['itemId'] as String? ?? '',
      brandId: json['brandId'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitValue: (json['unitValue'] ?? 0).toDouble(),
      lineTotal: (json['lineTotal'] ?? 0).toDouble(),
      image: json['image'] as String?,
      discount: (json['discount'])?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'brandId': brandId,
      'brandName': brandName,
      'quantity': quantity,
      'unitValue': unitValue,
      'lineTotal': lineTotal,
      'image': image,
    };
  }
}

class Cart {
  final String clientId;
  final List<CartItem> items;
  final double totalAmount;
  final int totalItems;
  final String currency;

  const Cart({
    required this.clientId,
    required this.items,
    required this.totalAmount,
    required this.totalItems,
    this.currency = 'INR',
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      clientId: json['clientId'] as String? ?? '',
      items: (json['items'] as List?)
              ?.map((e) => CartItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      totalItems: json['totalItems'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'INR',
    );
  }
}

class AddToCartRequest {
  final String brandId;
  final String brandName;
  final int quantity;
  final double unitValue;
  final String? image;

  const AddToCartRequest({
    required this.brandId,
    required this.brandName,
    required this.quantity,
    required this.unitValue,
    this.image,
  });

  Map<String, dynamic> toJson() {
    return {
      'brandId': brandId,
      'brandName': brandName,
      'quantity': quantity,
      'unitValue': unitValue,
      'image': image,
    };
  }
}

class OrderRequest {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;

  const OrderRequest({required this.order, required this.items});

  Map<String, dynamic> toJson() => {'order': order, 'items': items};
}
