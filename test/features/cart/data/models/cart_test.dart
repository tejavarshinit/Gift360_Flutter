import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/cart/data/models/cart.dart';

void main() {
  group('CartItem discount field presence', () {
    test('preserves an explicitly null discount as loaded', () {
      final item = CartItem.fromJson({
        'itemId': 'item-1',
        'brandId': 'brand-1',
        'brandName': 'Brand',
        'quantity': 1,
        'unitValue': 100,
        'lineTotal': 100,
        'discount': null,
      });

      expect(item.discount, isNull);
      expect(item.hasDiscountField, isTrue);
    });

    test('distinguishes an absent discount from an explicit null', () {
      final item = CartItem.fromJson({
        'itemId': 'item-1',
        'brandId': 'brand-1',
        'brandName': 'Brand',
        'quantity': 1,
        'unitValue': 100,
        'lineTotal': 100,
      });

      expect(item.discount, isNull);
      expect(item.hasDiscountField, isFalse);
    });
  });
}
