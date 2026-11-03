import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local terminal-state floor for gifting/scratch vouchers.
///
/// Port of React `src/lib/voucherStateStore.ts`.
///
/// WHY: POST /coupons/scratch and /coupons/gift write to ONE of two server
/// tables — the per-card row (giftcard_coupon_items, when an itemId was
/// known) or the shared order-item flags (giftcard_order_items, legacy path
/// when card-items hadn't loaded / failed). The Orders read then picks a
/// source based on whether ITS card-items fetch succeeded this time around.
/// Whenever write and read land on DIFFERENT sources, the previously
/// revealed/gifted voucher rendered as PENDING again ("starts from scratch").
///
/// Every confirmed terminal outcome (success or 409 already-terminal) is
/// recorded under BOTH keys — the exact card (itemId) and the order item
/// (orderItemId) — and the voucher readers union it with whatever server
/// flags they got, so a terminal state NEVER reverts to PENDING. Mirrors the
/// `g360_redeemed_vouchers` localStorage pattern used for redeemed vouchers.
const _voucherStateStorageKey = 'g360_voucher_terminal_states';

class VoucherTerminalStore {
  VoucherTerminalStore._();

  static final Map<String, String> _byItem = {};
  static final Map<String, String> _byOrderItem = {};
  static bool _loaded = false;

  /// Load once (in-memory afterwards so reads stay synchronous during build).
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_voucherStateStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final byItem = decoded['byItem'];
      final byOrderItem = decoded['byOrderItem'];
      if (byItem is Map) {
        byItem.forEach((k, v) => _byItem[k.toString()] = v.toString());
      }
      if (byOrderItem is Map) {
        byOrderItem.forEach((k, v) => _byOrderItem[k.toString()] = v.toString());
      }
    } catch (_) {
      // Corrupt/absent local data — start empty, same as React's try/catch.
    }
  }

  /// Record a confirmed reveal/gift under both the card and order-item keys.
  static Future<void> record({
    String? orderItemId,
    String? itemId,
    required bool scratched,
  }) async {
    final state = scratched ? 'SCRATCHED' : 'GIFTED';
    final cardId = (itemId ?? '').trim();
    final itemOrderId = (orderItemId ?? '').trim();
    if (cardId.isEmpty && itemOrderId.isEmpty) return;
    if (cardId.isNotEmpty) _byItem[cardId] = state;
    if (itemOrderId.isNotEmpty) _byOrderItem[itemOrderId] = state;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _voucherStateStorageKey,
        jsonEncode({'byItem': _byItem, 'byOrderItem': _byOrderItem}),
      );
    } catch (_) {
      // Storage unavailable — the in-memory copy still protects this session.
    }
  }

  /// Exact-card lookup — for reads that matched a per-card row.
  static String? cardState(String? itemId) =>
      (itemId == null || itemId.isEmpty) ? null : _byItem[itemId];

  /// Order-item lookup — for reads that fell back to the shared flags.
  static String? orderItemState(String? orderItemId) =>
      (orderItemId == null || orderItemId.isEmpty) ? null : _byOrderItem[orderItemId];
}
