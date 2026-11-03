import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/data/repositories/device_token_api.dart';
import 'package:gift360/features/notifications/presentation/services/push_notification_service.dart';

void main() {
  test(
    'Firebase unavailable disables notifications without crashing',
    () async {
      final service = PushNotificationService(
        firebaseAvailable: false,
        deviceTokenApi: DeviceTokenApi(baseUrl: 'http://localhost:8081'),
      );

      await expectLater(service.initialize(), completes);
      service.dispose();
    },
  );
}
