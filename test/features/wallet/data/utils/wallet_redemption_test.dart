import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/wallet/data/utils/wallet_redemption.dart';

void main() {
  group('walletItemCashbackScale4', () {
    test('rounds each item cashback to four decimal places', () {
      expect(walletItemCashbackScale4(100, 50), 500000);
      expect(walletItemCashbackScale4(0.01, 0.5), 1);
    });
  });

  group('walletRedemptionCapPaise', () {
    test('preserves fractional redemption percentages', () {
      expect(walletRedemptionCapPaise(20000, 50.4, 10), 101);
    });

    test('caps the percentage result at the configured maximum', () {
      expect(walletRedemptionCapPaise(20000, 75.5, 1), 100);
    });

    test('rounds the percentage result to the nearest paise', () {
      expect(walletRedemptionCapPaise(10000, 50.5, 10), 51);
    });

    test('rounds half a paise upward and supports zero cashback', () {
      expect(walletRedemptionCapPaise(100, 50, 10), 1);
      expect(walletRedemptionCapPaise(0, 50, 100), 0);
    });
  });
}
