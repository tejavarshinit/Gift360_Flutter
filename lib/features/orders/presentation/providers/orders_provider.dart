import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/brands/presentation/providers/brands_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';

const _redeemedStorageKey = 'g360_redeemed_vouchers';

/// Fetches the client's orders via POST /v1/neworders (same endpoint the
/// React Orders page calls directly on `brandApi`), sorted newest-first.
final ordersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.clientId.isEmpty) return [];

  final api = ref.watch(brandsApiProvider);
  final raw = await api.fetchNewOrders(user.clientId, timeline: 12);
  final orders = raw.map((e) => Map<String, dynamic>.from(e)).toList();

  orders.sort((a, b) {
    final da = DateTime.tryParse(orderCreatedAt(a) ?? '') ?? DateTime(1970);
    final db = DateTime.tryParse(orderCreatedAt(b) ?? '') ?? DateTime(1970);
    return db.compareTo(da);
  });

  return orders;
});

/// One entry in the "Redeemed" tab — created once a buyer confirms a
/// voucher has been used at the merchant (mirrors `handleRedeemed()` +
/// the `REDEEMED_KEY` localStorage list in Orders.tsx).
class RedeemedEntry {
  final String id;
  final String orderNumber;
  final String brandName;
  final double amount;
  final String? image;
  final List<VoucherView> vouchers;
  final String redeemedAt;

  const RedeemedEntry({
    required this.id,
    required this.orderNumber,
    required this.brandName,
    required this.amount,
    required this.vouchers,
    required this.redeemedAt,
    this.image,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'brandName': brandName,
        'amount': amount,
        'image': image,
        'vouchers': vouchers.map((v) => v.toJson()).toList(),
        'redeemedAt': redeemedAt,
      };

  factory RedeemedEntry.fromJson(Map<String, dynamic> json) => RedeemedEntry(
        id: json['id']?.toString() ?? '',
        orderNumber: json['orderNumber']?.toString() ?? '',
        brandName: json['brandName']?.toString() ?? 'Voucher',
        amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0,
        image: json['image']?.toString(),
        vouchers: ((json['vouchers'] as List?) ?? [])
            .map((e) => VoucherView.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        redeemedAt: json['redeemedAt']?.toString() ?? '',
      );
}

class RedeemedVouchersNotifier extends StateNotifier<List<RedeemedEntry>> {
  RedeemedVouchersNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_redeemedStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List;
      state = decoded
          .map((e) => RedeemedEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Corrupt/absent local data — start empty, same as the React try/catch.
    }
  }

  Future<void> add(RedeemedEntry entry) async {
    final updated = [entry, ...state];
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _redeemedStorageKey,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }

  bool isRedeemed(String orderIdOrNumber) =>
      state.any((r) => r.id == orderIdOrNumber || r.orderNumber == orderIdOrNumber);
}

final redeemedVouchersProvider =
    StateNotifierProvider<RedeemedVouchersNotifier, List<RedeemedEntry>>((ref) {
  return RedeemedVouchersNotifier();
});
