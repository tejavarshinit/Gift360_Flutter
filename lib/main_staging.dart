import 'config/app_flavor.dart';
import 'main.dart' as app;

/// Staging flavor. Real auth API, real JWT, and UPI are enabled.
void main() {
  AppFlavorConfig.use(AppFlavor.staging);
  app.main();
}
