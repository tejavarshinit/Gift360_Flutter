import 'config/app_flavor.dart';
import 'main.dart' as app;

/// Dev flavor. OTP is 1234 and UPI is off. There is no dev API.
void main() {
  AppFlavorConfig.use(AppFlavor.dev);
  app.main();
}
