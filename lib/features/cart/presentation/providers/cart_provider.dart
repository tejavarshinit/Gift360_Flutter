import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/data/repositories/cart_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

final cartApiProvider = Provider<CartApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return CartApi(dio);
});

class CartNotifier extends StateNotifier<Cart?> {
  final CartApi _api;
  final String? _clientId;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  CartNotifier(this._api, this._clientId) : super(null) {
    if (_clientId != null) _loadCart();
  }

  Future<void> _loadCart() async {
    if (_clientId == null) return;
    try {
      state = await _api.getCart(_clientId!);
    } catch (_) {}
  }

  Future<void> addToCart(AddToCartRequest item) async {
    if (_clientId == null) {
      await _addToGuestCart(item);
      return;
    }
    try {
      state = await _api.addToCart(_clientId!, item);
    } catch (_) {}
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (_clientId == null || state == null) return;
    try {
      state = await _api.updateQuantity(_clientId!, itemId, quantity);
    } catch (_) {}
  }

  Future<void> removeFromCart(String itemId) async {
    if (_clientId == null || state == null) return;
    try {
      state = await _api.removeFromCart(_clientId!, itemId);
    } catch (_) {}
  }

  Future<void> clearCart() async {
    if (_clientId == null) return;
    try {
      await _api.clearCart(_clientId!);
      state = const Cart(clientId: '', items: [], totalAmount: 0, totalItems: 0);
    } catch (_) {}
  }

  Future<void> _addToGuestCart(AddToCartRequest item) async {
    try {
      final stored = await _storage.read(key: 'guestCart');
      final List<dynamic> guestCart = stored != null ? jsonDecode(stored) : [];
      final existingIndex = guestCart.indexWhere(
        (i) => i['brandId'] == item.brandId && i['unitValue'] == item.unitValue,
      );
      if (existingIndex >= 0) {
        guestCart[existingIndex]['quantity'] += item.quantity;
      } else {
        guestCart.add(item.toJson());
      }
      await _storage.write(key: 'guestCart', value: jsonEncode(guestCart));
    } catch (_) {}
  }
}

final cartProvider = StateNotifierProvider.autoDispose<CartNotifier, Cart?>((ref) {
  final api = ref.watch(cartApiProvider);
  final user = ref.watch(authProvider);
  return CartNotifier(api, user?.clientId);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart?.totalItems ?? 0;
});
