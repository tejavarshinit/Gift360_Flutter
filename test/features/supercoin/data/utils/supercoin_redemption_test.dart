import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/supercoin/data/utils/supercoin_redemption.dart';

void main() {
  group('supercoinItemCapCoins', () {
    test('calculates caps using the brand share and multiplier', () {
      expect(
        supercoinItemCapCoins(itemTotal: 100, capPercent: 20, multiplier: 1.25),
        25,
      );
      expect(
        supercoinItemCapCoins(
          itemTotal: 75.99,
          capPercent: 12.5,
          multiplier: 2.4,
        ),
        23,
      );
    });

    test('ceil-rounds small positive caps to one coin', () {
      expect(
        supercoinItemCapCoins(
          itemTotal: 0.01,
          capPercent: 20,
          multiplier: 1.25,
        ),
        1,
      );
    });
  });
}
