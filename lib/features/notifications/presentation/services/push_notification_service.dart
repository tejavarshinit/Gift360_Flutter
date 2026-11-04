import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';
import 'package:gift360/features/notifications/data/models/push_notification_payload.dart';

const _androidChannelId = 'karatly_default';
const _androidChannelName = 'Gift360 notifications';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  if (message.notification != null) return;

  final payload = PushNotificationPayload.fromData(message.data);
  final title = payload.title;
  final body = payload.body;
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  final notifications = FlutterLocalNotificationsPlugin();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Purchase, account, and service updates.',
      importance: Importance.high,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }
  await notifications.initialize(settings: _notificationInitializationSettings);
  await notifications.show(
    id: message.messageId.hashCode & 0x7fffffff,
    title: title,
    body: body,
    payload: jsonEncode(message.data),
    notificationDetails: _localNotificationDetails,
  );
}

const _notificationInitializationSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);

const _localNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _androidChannelId,
    _androidChannelName,
    channelDescription: 'Purchase, account, and service updates.',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

class PushNotificationService {
  final bool firebaseAvailable;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseMessaging? _messaging;
  late final NotificationTapRouter _tapRouter = NotificationTapRouter(
    onNavigate: (destination) => _navigationHandler(destination),
  );
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;

  PushNotificationService({
    required this.firebaseAvailable,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseMessaging? messaging,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _messaging =
           messaging ?? (firebaseAvailable ? FirebaseMessaging.instance : null);

  void setNavigationHandler(void Function(String destination) handler) {
    // Keep the tap coordinator independent of GoRouter for unit testing.
    _navigationHandler = handler;
  }

  void Function(String destination) _navigationHandler = (_) {};

  void setNavigationReady(bool ready) {
    _tapRouter.setNavigationReady(ready);
  }

  void updateAuthenticatedUser(AuthUser? user) {
    _tapRouter.setAuthenticated(user != null);
  }

  Future<void> initialize() async {
    if (!firebaseAvailable || _initialized) return;
    final messaging = _messaging;
    if (messaging == null) {
      debugPrint(
        '[FCM] Notification handling is disabled: Firebase is unavailable.',
      );
      return;
    }
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      debugPrint(
        '[FCM] Notification handling is unsupported on this platform.',
      );
      return;
    }
    try {
      await _localNotifications.initialize(
        settings: _notificationInitializationSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const channel = AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Purchase, account, and service updates.',
          importance: Importance.high,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_showForegroundNotification(message)),
        onError: (Object error) =>
            debugPrint('[FCM] Foreground message stream failed: $error'),
      );
      _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleRemoteNotificationTap,
        onError: (Object error) =>
            debugPrint('[FCM] Notification tap stream failed: $error'),
      );
      // FCM's replacement stream emits an installation ID, not its messaging token.
      // ignore: deprecated_member_use
      _tokenSubscription = messaging.onTokenRefresh.listen(
        (token) {
          if (kDebugMode) debugPrint('[FCM] Refreshed device token: $token');
        },
        onError: (Object error) =>
            debugPrint('[FCM] Token refresh stream failed: $error'),
      );
      _initialized = true;

      await _requestPermissionAndLogToken(messaging);

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final localPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          localPayload != null) {
        _handleLocalPayload(localPayload);
      }

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleRemoteNotificationTap(initialMessage);
    } catch (error, stackTrace) {
      debugPrint('[FCM] Notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestPermissionAndLogToken(
    FirebaseMessaging messaging,
  ) async {
    try {
      final settings = await messaging.getNotificationSettings();
      var status = settings.authorizationStatus;
      if (status == AuthorizationStatus.notDetermined) {
        final requested = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        status = requested.authorizationStatus;
      }
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        debugPrint('[FCM] Notification permission is not enabled.');
        return;
      }
      if (kIsWeb && AppConfig.firebaseWebVapidKey.trim().isEmpty) {
        debugPrint('[FCM] FIREBASE_WEB_VAPID_KEY is not configured.');
        return;
      }
      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: kIsWeb && AppConfig.firebaseWebVapidKey.isNotEmpty
            ? AppConfig.firebaseWebVapidKey
            : null,
      );
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Firebase did not return a registration token.');
        return;
      }
      if (kDebugMode) debugPrint('[FCM] Device token: $token');
    } catch (error, stackTrace) {
      debugPrint('[FCM] Could not retrieve the device token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final payload = PushNotificationPayload.fromData(message.data);
    final title = message.notification?.title ?? payload.title;
    final body = message.notification?.body ?? payload.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    try {
      await _localNotifications.show(
        id: message.messageId.hashCode & 0x7fffffff,
        title: title,
        body: body,
        payload: jsonEncode(message.data),
        notificationDetails: _localNotificationDetails,
      );
    } catch (error, stackTrace) {
      debugPrint('[FCM] Could not display foreground notification: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleRemoteNotificationTap(RemoteMessage message) {
    _tapRouter.handleTap(PushNotificationPayload.fromData(message.data));
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) _handleLocalPayload(payload);
  }

  void _handleLocalPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        _tapRouter.handleTap(PushNotificationPayload.fromData(decoded));
      } else {
        debugPrint(
          '[FCM] Ignoring local notification tap with invalid payload.',
        );
      }
    } on FormatException catch (error) {
      debugPrint(
        '[FCM] Ignoring local notification tap with invalid JSON: $error',
      );
    }
  }

  void dispose() {
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_tapSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  throw UnimplementedError('Override with the app push-notification service.');
});
