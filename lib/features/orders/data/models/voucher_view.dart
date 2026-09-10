// Mirrors the voucher/order helper logic in the React reference app's
// `src/pages/Orders.tsx` (extractVouchers, getImageUrl, mapOrder helpers)
// and `src/types/order.ts` (VoucherState, DeliveryChannel).
import 'package:gift360/core/utils/image_url_helper.dart';

/// Terminal state machine for a single voucher/coupon.
///
///   pending   -> scratch surface shown; tapping opens the ScratchGate
///   scratched -> terminal; revealed code shown, no gate
///   gifted    -> terminal; locked card shown, no gate
enum VoucherState { pending, scratched, gifted }

/// Delivery channel for the gifting flow.
enum DeliveryChannel { whatsapp, email, both }

extension DeliveryChannelApi on DeliveryChannel {
  String get apiValue {
    switch (this) {
      case DeliveryChannel.whatsapp:
        return 'WHATSAPP';
      case DeliveryChannel.email:
        return 'EMAIL';
      case DeliveryChannel.both:
        return 'BOTH';
    }
  }
}

/// One physical voucher/coupon code extracted from an order item.
class VoucherView {
  final String key;
  final String orderItemId;
  final String brandName;
  final String cardNumber;
  final String cardPin;
  final String expiryDate;
  final String amount;
  final bool isScratched;
  final bool isGift;

  const VoucherView({
    required this.key,
    required this.orderItemId,
    required this.brandName,
    required this.cardNumber,
    required this.cardPin,
    required this.expiryDate,
    required this.amount,
    required this.isScratched,
    required this.isGift,
  });

  VoucherState get initialState {
    if (isScratched) return VoucherState.scratched;
    if (isGift) return VoucherState.gifted;
    return VoucherState.pending;
  }

  VoucherView copyWith({bool? isScratched, bool? isGift}) => VoucherView(
    key: key,
    orderItemId: orderItemId,
    brandName: brandName,
    cardNumber: cardNumber,
    cardPin: cardPin,
    expiryDate: expiryDate,
    amount: amount,
    isScratched: isScratched ?? this.isScratched,
    isGift: isGift ?? this.isGift,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'orderItemId': orderItemId,
    'brandName': brandName,
    'cardNumber': cardNumber,
    'cardPin': cardPin,
    'expiryDate': expiryDate,
    'amount': amount,
    'isScratched': isScratched,
    'isGift': isGift,
  };

  factory VoucherView.fromJson(Map<String, dynamic> json) => VoucherView(
    key: json['key']?.toString() ?? '',
    orderItemId: json['orderItemId']?.toString() ?? '',
    brandName: json['brandName']?.toString() ?? '',
    cardNumber: json['cardNumber']?.toString() ?? '',
    cardPin: json['cardPin']?.toString() ?? '',
    expiryDate: json['expiryDate']?.toString() ?? '',
    amount: json['amount']?.toString() ?? '',
    isScratched: json['isScratched'] == true,
    isGift: json['isGift'] == true,
  );
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _asList(dynamic v) => v is List ? v : const [];

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

/// Equivalent of `extractVouchers()` in Orders.tsx — walks
/// order.items[].gift_voucher_item_coupon_details[].items[] and flattens
/// every physical voucher code into a [VoucherView].
List<VoucherView> extractVouchers(
  Map<String, dynamic> order, {
  Map<String, List<Map<String, dynamic>>> cardItemsByOrderItem = const {},
}) {
  final results = <VoucherView>[];
  for (final rawItem in _asList(order['items'])) {
    final item = _asMap(rawItem);
    final meta = _asMap(item['meta']);
    final orderItemId = item['order_item_id']?.toString() ?? '';
    final brandName = meta['brand_name']?.toString() ?? '';
    final isScratched = _asBool(item['is_scratched']);
    final isGift = _asBool(item['is_gift']);
    final cardItems =
        cardItemsByOrderItem[orderItemId] ?? const <Map<String, dynamic>>[];

    // Current API shape: items[].coupons[].vd_raw_response.brand_details[].items[].
    final coupons = _asList(item['coupons']);
    for (var ci = 0; ci < coupons.length; ci++) {
      final coupon = _asMap(coupons[ci]);
      for (final rawBrand in _asList(
        _asMap(coupon['vd_raw_response'])['brand_details'],
      )) {
        final brand = _asMap(rawBrand);
        for (var vi = 0; vi < _asList(brand['items']).length; vi++) {
          final v = _asMap(_asList(brand['items'])[vi]);
          Map<String, dynamic>? card;
          for (final candidate in cardItems) {
            if (candidate['cardIndex']?.toString() == vi.toString()) {
              card = candidate;
              break;
            }
          }
          results.add(
            VoucherView(
              key: '$orderItemId-$ci-$vi',
              orderItemId: orderItemId,
              brandName: brandName,
              cardNumber: v['getCardNo']?.toString() ?? '',
              cardPin: v['getCardPin']?.toString() ?? '',
              expiryDate: v['getExpiryDate']?.toString() ?? '',
              amount: v['balanceTotal']?.toString() ?? '',
              isScratched:
                  _asBool(card?['isScratched']) ||
                  _asBool(card?['is_scratched']) ||
                  (card == null && isScratched),
              isGift:
                  _asBool(card?['isGift']) ||
                  _asBool(card?['is_gift']) ||
                  (card == null && isGift),
            ),
          );
        }
      }
    }
    if (coupons.isNotEmpty) continue;

    final groups = _asList(item['gift_voucher_item_coupon_details']);
    for (var ci = 0; ci < groups.length; ci++) {
      final g = _asMap(groups[ci]);
      final vItems = _asList(g['items']);
      for (var vi = 0; vi < vItems.length; vi++) {
        final v = _asMap(vItems[vi]);
        Map<String, dynamic>? card;
        for (final candidate in cardItems) {
          if (candidate['cardIndex']?.toString() == vi.toString()) {
            card = candidate;
            break;
          }
        }
        results.add(
          VoucherView(
            key: '$orderItemId-$ci-$vi',
            orderItemId: orderItemId,
            brandName: brandName,
            cardNumber: v['getCardNo']?.toString() ?? '',
            cardPin: v['getCardPin']?.toString() ?? '',
            expiryDate: v['getExpiryDate']?.toString() ?? '',
            amount: v['balanceTotal']?.toString() ?? '',
            isScratched:
                _asBool(card?['isScratched']) ||
                _asBool(card?['is_scratched']) ||
                (card == null && isScratched),
            isGift:
                _asBool(card?['isGift']) ||
                _asBool(card?['is_gift']) ||
                (card == null && isGift),
          ),
        );
      }
    }
  }
  return results;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// Equivalent of the `total_amount` derivation in `mapOrder()`.
double orderTotalAmount(Map<String, dynamic> order) {
  final pricing = _asMap(order['pricing']);
  if (pricing['final_payable'] != null)
    return _toDouble(pricing['final_payable']);
  if (pricing['subtotal'] != null) return _toDouble(pricing['subtotal']);
  if (order['total_amount'] != null) return _toDouble(order['total_amount']);
  return 0;
}

Map<String, dynamic> firstItemMeta(Map<String, dynamic> order) {
  final items = _asList(order['items']);
  if (items.isEmpty) return {};
  return _asMap(_asMap(items.first)['meta']);
}

String orderBrandName(Map<String, dynamic> order) {
  final meta = firstItemMeta(order);
  final name = meta['brand_name']?.toString();
  if (name != null && name.isNotEmpty) return name;
  final orderNumber = order['order_number']?.toString() ?? '';
  final suffix = orderNumber.length > 8
      ? orderNumber.substring(orderNumber.length - 8)
      : orderNumber;
  return 'Order #$suffix';
}

String? orderRedeemSteps(Map<String, dynamic> order) {
  final meta = firstItemMeta(order);
  final v =
      meta['redeem_steps'] ?? meta['RedeemSteps'] ?? meta['how_to_redeem'];
  final s = v?.toString();
  return (s != null && s.isNotEmpty) ? s : null;
}

/// Equivalent of `getImageUrl()` in Orders.tsx.
String? orderItemImageUrl(Map<String, dynamic> meta) {
  final imageUrl = meta['ImageUrl']?.toString();
  if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;

  final brandImageUrl = meta['brand_image_url']?.toString();
  if (brandImageUrl != null && brandImageUrl.isNotEmpty) return brandImageUrl;

  final fromImage = resolveBrandImageUrl(meta['image']);
  if (fromImage != null) return fromImage;

  final fromImages = resolveBrandImageUrl(meta['Images']);
  if (fromImages != null) return fromImages;

  final fromLegacy = resolveBrandImageUrl(meta['Image'] ?? meta['images']);
  if (fromLegacy != null) return fromLegacy;

  final brandId =
      meta['BrandId']?.toString() ??
      meta['brandId']?.toString() ??
      meta['brand_id']?.toString();
  if (brandId != null && brandId.isNotEmpty) {
    return 'https://images.gift360.io/$brandId.png';
  }
  return null;
}

String orderStatus(Map<String, dynamic> order) =>
    (order['status']?.toString() ?? '').toUpperCase();

String? orderCreatedAt(Map<String, dynamic> order) =>
    order['created_at']?.toString() ?? order['createdAt']?.toString();

String orderId(Map<String, dynamic> order) =>
    order['order_id']?.toString() ?? order['order_number']?.toString() ?? '';
