import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/presentation/services/push_notification_service.dart';

void main() {
  test(
    'Firebase unavailable disables notifications without crashing',
    () async {
      final service = PushNotificationService(firebaseAvailable: false);

      await expectLater(service.initialize(), completes);
      service.dispose();
    },
  );
}
