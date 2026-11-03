import 'package:flutter_test/flutter_test.dart';
import 'package:gift360/features/notifications/data/models/push_notification_payload.dart';

void main() {
  group('PushNotificationPayload', () {
    test('routes a successful gold purchase to an existing order screen', () {
      final payload = PushNotificationPayload.fromData({
        'type': 'GOLD_PURCHASE',
        'orderId': 'ORD-123_abc',
        'status': 'SUCCESS',
        'grams': '2.5',
      });

      expect(payload.grams, '2.5');
      expect(payload.destination, '/my-orders/ORD-123_abc/checkout');
    });

    test(
      'falls back safely when the purchase order ID is invalid or absent',
      () {
        expect(
          PushNotificationPayload.fromData({
            'type': 'GOLD_PURCHASE',
            'status': 'SUCCESS',
            'orderId': '../profile',
          }).destination,
          '/my-orders',
        );
        expect(
          PushNotificationPayload.fromData({
            'type': 'GOLD_PURCHASE',
            'status': 'SUCCESS',
          }).destination,
          '/my-orders',
        );
      },
    );

    test('routes price and database-driven notifications defensively', () {
      expect(
        PushNotificationPayload.fromData({
          'type': 'GOLD_SILVER_PRICE_UPDATE',
        }).destination,
        '/notifications',
      );
      expect(
        PushNotificationPayload.fromData({
          'type': 'ORDER_STATUS',
          'notificationCode': 'ORDER_SUCCESS',
          'orderId': 'ORD123',
        }).destination,
        '/my-orders/ORD123/checkout',
      );
      expect(
        PushNotificationPayload.fromData({
          'type': 'UNRECOGNIZED',
          'notificationCode': 'UNRECOGNIZED',
        }).destination,
        '/notifications',
      );
    });

    test('accepts FCM data fields only when their values are strings', () {
      final payload = PushNotificationPayload.fromData({
        'type': 42,
        'orderId': 7,
        'notificationCode': '  PURCHASE  ',
      });

      expect(payload.type, isNull);
      expect(payload.orderId, isNull);
      expect(payload.notificationCode, 'PURCHASE');
      expect(payload.destination, '/notifications');
    });
  });

  group('NotificationTapRouter', () {
    test(
      'defers cold-start navigation until both auth and navigation are ready',
      () {
        final destinations = <String>[];
        final router = NotificationTapRouter(onNavigate: destinations.add);
        const payload = PushNotificationPayload(
          type: 'GOLD_PURCHASE',
          orderId: 'ORD123',
          status: 'SUCCESS',
        );

        router.handleTap(payload);
        router.setAuthenticated(true);
        expect(destinations, isEmpty);

        router.setNavigationReady(true);
        expect(destinations, ['/my-orders/ORD123/checkout']);
      },
    );

    test('holds taps until the user signs in and routes each tap once', () {
      final destinations = <String>[];
      final router = NotificationTapRouter(onNavigate: destinations.add)
        ..setNavigationReady(true);
      router.handleTap(const PushNotificationPayload(type: 'OTHER'));

      expect(destinations, isEmpty);
      router.setAuthenticated(true);
      expect(destinations, ['/notifications']);
      router.setAuthenticated(false);
      expect(destinations, hasLength(1));
    });
  });
}
