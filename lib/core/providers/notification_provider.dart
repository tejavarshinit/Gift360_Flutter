import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gift360/features/notifications/data/models/app_notification.dart';

const _storageKey = 'g360_notifications';

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final SharedPreferences _prefs;

  NotificationNotifier(this._prefs) : super([]) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList();
        state = list;
      } catch (_) {}
    }
  }

  void _save() {
    _prefs.setString(_storageKey, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void addNotification({
    String? title,
    required String message,
    String type = 'info',
    String? eventKey,
  }) {
    // Dedup: skip if same eventKey already exists
    if (eventKey != null && state.any((n) => n.eventKey == eventKey)) return;

    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title ?? (type == 'success' ? 'Congratulations!' : 'Notification'),
      message: message,
      type: type,
      createdAt: DateTime.now().toIso8601String(),
      eventKey: eventKey,
    );

    state = [notification, ...state].take(50).toList();
    _save();
  }

  void clearAll() {
    state = [];
    _save();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  throw UnimplementedError('Override with SharedPreferences in main.dart');
});
