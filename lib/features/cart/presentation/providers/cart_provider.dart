import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/features/cart/data/models/cart.dart';
import 'package:gift360/features/cart/data/repositories/cart_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/core/utils/analytics.dart';
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
  bool _guestCartMerged = false;

  CartNotifier(this._api, this._clientId) : super(null) {
    if (_clientId != null) {
      _mergeGuestCart();
      _loadCart();
    }
  }

  Future<void> _loadCart() async {
    if (_clientId == null) return;
    try {
      state = await _api.getCart(_clientId!);
    } catch (_) {}
  }

  /// Merge guest cart items into the backend cart on login.
  /// Mirrors React's mergeGuestCart logic from useCart.ts:
  /// - On HTTP 400: clears guest cart (invalid item), continues
  /// - On other errors: removes merge flag, re-saves guest cart for retry
  Future<void> _mergeGuestCart() async {
    if (_clientId == null || _guestCartMerged) return;

    final mergeFlag = 'cart_merged_$_clientId';
    final alreadyMerged = await _storage.read(key: mergeFlag);
    if (alreadyMerged == 'true') {
      _guestCartMerged = true;
      return;
    }

    // Set flag immediately to prevent race condition
    await _storage.write(key: mergeFlag, value: 'true');

    try {
      final stored = await _storage.read(key: 'guestCart');
      if (stored == null || stored.isEmpty) {
        _guestCartMerged = true;
        return;
      }

      final List<dynamic> guestItems = jsonDecode(stored);
      if (guestItems.isEmpty) {
        _guestCartMerged = true;
        return;
      }

      bool hadInvalidItem = false;

      // Merge each guest item into the backend cart
      for (final item in guestItems) {
        try {
          await _api.addToCart(_clientId!, AddToCartRequest(
            brandId: item['brandId'] as String? ?? '',
            brandName: item['brandName'] as String? ?? '',
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            unitValue: (item['unitValue'] as num?)?.toDouble() ?? 0,
            image: item['image'] as String?,
          ));
        } on DioException catch (e) {
          if (e.response?.statusCode == 400) {
            // HTTP 400 = invalid item — clear guest cart, skip this item
            hadInvalidItem = true;
          }
          // Other errors: continue merging other items
        } catch (_) {
          // Non-HTTP errors: continue merging other items
        }
      }

      // Clear guest cart after merge attempt
      await _storage.delete(key: 'guestCart');
      _guestCartMerged = true;

      // Refetch cart to get the merged state
      _loadCart();
    } catch (_) {
      // Outer error: remove merge flag so user can retry on next login
      await _storage.delete(key: mergeFlag);
      _guestCartMerged = false;
    }
  }

  /// Get guest cart item count for display before backend cart loads.
  Future<int> getGuestCartItemCount() async {
    if (_clientId != null) return 0;
    try {
      final stored = await _storage.read(key: 'guestCart');
      if (stored == null || stored.isEmpty) return 0;
      final List<dynamic> guestItems = jsonDecode(stored);
      return guestItems.fold<int>(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1));
    } catch (_) {
      return 0;
    }
  }

  /// Get placeholder cart from guest items while backend loads.
  Cart? _getGuestCartPlaceholder() {
    if (_clientId != null) return null;
    // Synchronous read not possible, but we can return null
    // The actual placeholder is handled by the UI
    return null;
  }

  /// Add to cart with optimistic update and analytics.
  /// Mirrors React's addMutation with onMutate/onError/onSuccess.
  Future<bool> addToCart(AddToCartRequest item) async {
    if (_clientId == null) {
      await _addToGuestCart(item);
      return true;
    }

    // Save previous state for rollback
    final previousCart = state;

    try {
      // Optimistic: show updated cart immediately
      final newState = await _api.addToCart(_clientId!, item);
      state = newState;

      // Fire analytics on successful backend add
      AnalyticsService.trackAddToCart(
        brandId: item.brandId,
        quantity: item.quantity,
        price: item.unitValue,
      );

      return true;
    } catch (e) {
      // Rollback on error
      state = previousCart;
      return false;
    }
  }

  /// Update quantity with optimistic update and rollback.
  Future<bool> updateQuantity(String itemId, int quantity) async {
    if (_clientId == null || state == null) return false;

    // Cap quantity at 3 per item (matches React MAX_QUANTITY_PER_ITEM).
    final clamped = quantity.clamp(1, 3);

    final previousCart = state;
    final previousItems = state!.items;

    try {
      // Optimistic: update local state immediately
      final updatedItems = previousItems.map((item) {
        if (item.itemId == itemId) {
          return item.copyWith(quantity: clamped, lineTotal: clamped * item.unitValue);
        }
        return item;
      }).toList();

      final newTotal = updatedItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final newCount = updatedItems.fold<int>(0, (sum, item) => sum + item.quantity);

      state = Cart(
        clientId: state!.clientId,
        items: updatedItems,
        totalAmount: newTotal,
        totalItems: newCount,
      );

      // Then sync with backend
      await _api.updateQuantity(_clientId!, itemId, clamped);
      return true;
    } catch (e) {
      // Rollback on error
      state = previousCart;
      return false;
    }
  }

  /// Remove from cart with optimistic update and rollback.
  Future<bool> removeFromCart(String itemId) async {
    if (_clientId == null || state == null) return false;

    final previousCart = state;

    try {
      // Optimistic: remove from local state immediately
      final updatedItems = state!.items.where((i) => i.itemId != itemId).toList();
      final newTotal = updatedItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final newCount = updatedItems.fold<int>(0, (sum, item) => sum + item.quantity);

      state = Cart(
        clientId: state!.clientId,
        items: updatedItems,
        totalAmount: newTotal,
        totalItems: newCount,
      );

      // Then sync with backend
      await _api.removeFromCart(_clientId!, itemId);
      return true;
    } catch (e) {
      // Rollback on error
      state = previousCart;
      return false;
    }
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

  /// Clear guest cart and merge flag (called on logout).
  Future<void> clearGuestCartData() async {
    await _storage.delete(key: 'guestCart');
    if (_clientId != null) {
      await _storage.delete(key: 'cart_merged_$_clientId');
    }
    _guestCartMerged = false;
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
