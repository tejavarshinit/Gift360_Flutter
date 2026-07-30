import 'package:dio/dio.dart';
import 'package:gift360/features/cart/data/models/cart.dart';

class CartApi {
  final Dio _dio;

  CartApi(this._dio);

  Future<Cart> getCart(String clientId) async {
    final response = await _dio.post('/cart/$clientId');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> addToCart(String clientId, AddToCartRequest item) async {
    final response = await _dio.post('/cart/$clientId/add', data: item.toJson());
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> updateQuantity(String clientId, String itemId, int quantity) async {
    final response = await _dio.post('/cart/$clientId/update/$itemId', data: {'quantity': quantity});
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Cart> removeFromCart(String clientId, String itemId) async {
    final response = await _dio.post('/cart/$clientId/remove/$itemId');
    return Cart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> clearCart(String clientId) async {
    await _dio.post('/cart/$clientId/clear');
  }
}
