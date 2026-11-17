import 'config/app_flavor.dart';
import 'main.dart' as app;

/// Production flavor. Same path as [main.dart]: real APIs only.
void main() {
  AppFlavorConfig.use(AppFlavor.prod);
  app.main();
}
