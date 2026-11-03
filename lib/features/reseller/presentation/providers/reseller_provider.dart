import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/reseller/data/reseller_api.dart';
import 'package:gift360/features/reseller/data/reseller_store.dart';

/// Reseller session (separate from the consumer auth session).
class ResellerSessionNotifier extends StateNotifier<ResellerSession?> {
  ResellerSessionNotifier() : super(null) {
    _load();
  }

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> _load() async {
    final session = await ResellerStore.getSession();
    _loaded = true;
    if (mounted) state = session;
  }

  Future<void> setSession(ResellerSession session) async {
    await ResellerStore.saveSession(session);
    _loaded = true;
    state = session;
  }

  Future<void> clear() async {
    await ResellerStore.clearSession();
    state = null;
  }
}

final resellerSessionProvider =
    StateNotifierProvider<ResellerSessionNotifier, ResellerSession?>((ref) {
      return ResellerSessionNotifier();
    });

final resellerApiProvider = Provider<ResellerApi>((ref) {
  return ResellerApi(
    Dio(
      BaseOptions(
        baseUrl: AppConfig.brandApiUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    ),
    () => ref.read(resellerSessionProvider)?.token,
  );
});

/// Local reseller cart (server has no cart; orders are created from its lines).
class ResellerCartNotifier extends StateNotifier<List<ResellerCartItem>> {
  ResellerCartNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final items = await ResellerStore.getCart();
    if (mounted) state = items;
  }

  void _persist(List<ResellerCartItem> next) {
    state = next;
    ResellerStore.saveCart(next);
  }

  void add(ResellerCartItem item, {int? maxQuantity}) {
    final next = state
        .map((i) => ResellerCartItem.fromJson(i.toJson()))
        .toList();
    final quantityLimit = (maxQuantity ?? maxResellerQuantityPerSku)
        .clamp(1, maxResellerQuantityPerSku)
        .toInt();
    final idx = next.indexWhere((i) => i.brandSku == item.brandSku);
    if (idx >= 0) {
      final merged = next[idx].quantity + item.quantity;
      next[idx] = ResellerCartItem(
        brandSku: next[idx].brandSku,
        brandName: next[idx].brandName,
        image: next[idx].image,
        unitPrice: item.unitPrice,
        quantity: merged.clamp(1, quantityLimit).toInt(),
        discount: item.discount,
      );
    } else {
      next.add(
        ResellerCartItem(
          brandSku: item.brandSku,
          brandName: item.brandName,
          image: item.image,
          unitPrice: item.unitPrice,
          quantity: item.quantity.clamp(1, quantityLimit).toInt(),
          discount: item.discount,
        ),
      );
    }
    _persist(next);
  }

  void setQuantity(String brandSku, int quantity) {
    final q = quantity.clamp(1, maxResellerQuantityPerSku).toInt();
    final next = state.map((i) {
      final copy = ResellerCartItem.fromJson(i.toJson());
      if (copy.brandSku == brandSku) copy.quantity = q;
      return copy;
    }).toList();
    _persist(next);
  }

  void remove(String brandSku) {
    _persist(state.where((i) => i.brandSku != brandSku).toList());
  }

  Future<void> clear() async {
    state = const [];
    await ResellerStore.clearCart();
  }

  double get subtotal =>
      state.fold(0, (sum, i) => sum + i.unitPrice * i.quantity);
  double get total => state.fold(0, (sum, i) => sum + i.lineTotal);
  double get discount => subtotal - total;
  int get count => state.fold(0, (sum, i) => sum + i.quantity);
}

final resellerCartProvider =
    StateNotifierProvider<ResellerCartNotifier, List<ResellerCartItem>>((ref) {
      return ResellerCartNotifier();
    });
