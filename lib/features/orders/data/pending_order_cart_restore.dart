import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/presentation/providers/cart_provider.dart';

const _dismissedPendingKey = 'g360_dismissed_pending_orders';

Map<String, dynamic> parseOrderItemMeta(dynamic meta) {
  if (meta == null) return {};
  if (meta is Map) return Map<String, dynamic>.from(meta);
  if (meta is String && meta.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(meta);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}

String? extractOrderBrandId(Map<String, dynamic> item, Map<String, dynamic> meta) {
  const keys = ['BrandId', 'brandId', 'brand_id', 'BrandID'];
  for (final key in keys) {
    final raw = item[key] ?? meta[key];
    final value = raw?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

double extractOrderUnitValue(
  Map<String, dynamic> item,
  Map<String, dynamic> meta,
  int quantity,
) {
  num? asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  for (final key in [
    'unitValue',
    'unit_value',
    'faceValue',
    'face_value',
    'amount',
    'voucher_amount',
  ]) {
    final n = asNum(item[key] ?? meta[key]);
    if (n != null && n > 0) return n.toDouble();
  }

  final line = asNum(item['lineTotal'] ?? item['line_total']);
  if (line != null && line > 0 && quantity > 0) {
    return line.toDouble() / quantity;
  }

  // Some pending payloads only keep denomination inside meta as a string.
  for (final key in ['denomination', 'Denomination', 'value', 'Value']) {
    final n = asNum(meta[key]);
    if (n != null && n > 0) return n.toDouble();
  }
  return 0;
}

int extractOrderQuantity(Map<String, dynamic> item) {
  final q = item['quantity'];
  if (q is num) return q.toInt().clamp(1, 3);
  if (q is String) return (int.tryParse(q) ?? 1).clamp(1, 3);
  return 1;
}

double _orderRootAmount(Map<String, dynamic> order) {
  num? asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  final pricing =
      order['pricing'] is Map ? Map<String, dynamic>.from(order['pricing'] as Map) : null;
  final fromPricing = asNum(pricing?['final_payable'] ?? pricing?['subtotal']);
  if (fromPricing != null && fromPricing > 0) return fromPricing.toDouble();

  final root = asNum(
    order['total_amount'] ??
        order['totalAmount'] ??
        order['amount'] ??
        order['order_amount'],
  );
  return (root != null && root > 0) ? root.toDouble() : 0;
}

/// Result of moving a pending order's items into the shopping cart.
class PendingCartRestoreResult {
  final int addedCount;
  final String? orderNumber;
  final String? error;

  const PendingCartRestoreResult({
    required this.addedCount,
    this.orderNumber,
    this.error,
  });

  bool get success => addedCount > 0;
}

Future<Set<String>> loadDismissedPendingOrders() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_dismissedPendingKey) ?? const [];
  return list.toSet();
}

Future<void> dismissPendingOrder(String orderNumber) async {
  final trimmed = orderNumber.trim();
  if (trimmed.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_dismissedPendingKey) ?? <String>[];
  if (!list.contains(trimmed)) {
    list.add(trimmed);
    await prefs.setStringList(_dismissedPendingKey, list);
  }
}

String? orderNumberOf(Map<String, dynamic> order) {
  final n =
      order['order_number']?.toString() ?? order['orderNumber']?.toString();
  final trimmed = n?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Re-add pending order line items into cart. Uses only data already on the
/// order object (avoids the 401 order-details call).
Future<PendingCartRestoreResult> restorePendingOrderToCart({
  required Map<String, dynamic> order,
  required CartNotifier cart,
}) async {
  final orderNumber = orderNumberOf(order);
  final items = order['items'];
  if (items is! List || items.isEmpty) {
    return PendingCartRestoreResult(
      addedCount: 0,
      orderNumber: orderNumber,
      error: 'No items found on this pending order.',
    );
  }

  var added = 0;
  String? lastError;

  for (final raw in items) {
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    final meta = parseOrderItemMeta(item['meta']);
    final brandId = extractOrderBrandId(item, meta);
    if (brandId == null || brandId.isEmpty) {
      lastError = 'Missing brand on order item.';
      debugPrint('Pending→cart skip: no brandId in $item / $meta');
      continue;
    }

    final quantity = extractOrderQuantity(item);
    var unitValue = extractOrderUnitValue(item, meta, quantity);
    // Single-item pending orders often only expose amount on the order root.
    if (unitValue <= 0) {
      final orderAmount = _orderRootAmount(order);
      if (orderAmount > 0) {
        unitValue = orderAmount / quantity;
      }
    }
    if (unitValue <= 0) {
      lastError = 'Missing amount on order item.';
      debugPrint('Pending→cart skip: no unitValue for $brandId');
      continue;
    }

    final brandName =
        (meta['brand_name'] ??
                meta['BrandName'] ??
                item['brandName'] ??
                item['brand_name'] ??
                'Voucher')
            .toString();
    final image = (meta['ImageUrl'] ??
            meta['brand_image_url'] ??
            meta['image'] ??
            meta['Images'] ??
            item['image'])
        ?.toString();

    final ok = await cart.addToCart(
      AddToCartRequest(
        brandId: brandId,
        brandName: brandName,
        quantity: quantity,
        unitValue: unitValue,
        image: image,
      ),
    );
    if (ok) {
      added++;
    } else {
      lastError = 'Cart API rejected $brandName.';
      debugPrint('Pending→cart add failed for $brandId $brandName $unitValue');
    }
  }

  if (added > 0 && orderNumber != null) {
    await dismissPendingOrder(orderNumber);
  }

  return PendingCartRestoreResult(
    addedCount: added,
    orderNumber: orderNumber,
    error: added == 0 ? (lastError ?? 'Could not add items to cart.') : null,
  );
}
