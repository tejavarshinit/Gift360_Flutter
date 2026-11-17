import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/config/app_flavor.dart';

void main() {
  tearDown(() => AppFlavorConfig.use(AppFlavor.prod));

  test('prod keeps real OTP and UPI', () {
    AppFlavorConfig.use(AppFlavor.prod);
    expect(AppFlavorConfig.usesMockOtp, isFalse);
    expect(AppFlavorConfig.allowsUpi, isTrue);
  });

  test('staging keeps real OTP and UPI', () {
    AppFlavorConfig.use(AppFlavor.staging);
    expect(AppFlavorConfig.usesMockOtp, isFalse);
    expect(AppFlavorConfig.allowsUpi, isTrue);
  });

  test('dev uses OTP 1234 and blocks UPI', () {
    AppFlavorConfig.use(AppFlavor.dev);
    expect(AppFlavorConfig.usesMockOtp, isTrue);
    expect(AppFlavorConfig.allowsUpi, isFalse);
    expect(AppFlavorConfig.devOtp, '1234');
  });
}
