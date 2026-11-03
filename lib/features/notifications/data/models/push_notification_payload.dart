class PushNotificationPayload {
  final String? type;
  final String? notificationCode;
  final String? orderId;
  final String? status;
  final String? grams;
  final String? title;
  final String? body;

  const PushNotificationPayload({
    this.type,
    this.notificationCode,
    this.orderId,
    this.status,
    this.grams,
    this.title,
    this.body,
  });

  factory PushNotificationPayload.fromData(Map<String, dynamic> data) {
    String? readString(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    return PushNotificationPayload(
      type: readString('type')?.toUpperCase(),
      notificationCode: readString('notificationCode'),
      orderId: readString('orderId'),
      status: readString('status')?.toUpperCase(),
      grams: readString('grams'),
      title: readString('title'),
      body: readString('body'),
    );
  }

  String get destination {
    final order = _safeOrderId(orderId);
    if (type == 'GOLD_PURCHASE') {
      if (status == 'SUCCESS' && order != null) {
        return '/my-orders/$order/checkout';
      }
      return '/my-orders';
    }
    if (type == 'GOLD_SILVER_PRICE_UPDATE') return '/notifications';
    if (order != null) return '/my-orders/$order/checkout';
    return '/notifications';
  }

  static String? _safeOrderId(String? value) {
    if (value == null || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
      return null;
    }
    return value;
  }
}

class NotificationTapRouter {
  final void Function(String destination) onNavigate;

  bool _navigationReady = false;
  bool _authenticated = false;
  PushNotificationPayload? _pending;

  NotificationTapRouter({required this.onNavigate});

  void setNavigationReady(bool ready) {
    _navigationReady = ready;
    _dispatchIfReady();
  }

  void setAuthenticated(bool authenticated) {
    _authenticated = authenticated;
    _dispatchIfReady();
  }

  void handleTap(PushNotificationPayload payload) {
    _pending = payload;
    _dispatchIfReady();
  }

  void _dispatchIfReady() {
    if (!_navigationReady || !_authenticated || _pending == null) return;
    final payload = _pending!;
    _pending = null;
    onNavigate(payload.destination);
  }
}
