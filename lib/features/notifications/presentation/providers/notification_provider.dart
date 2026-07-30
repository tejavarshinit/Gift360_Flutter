import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  NotificationNotifier() : super([]);

  void addNotification(Map<String, dynamic> notification) {
    state = [notification, ...state];
  }

  void clearNotifications() {
    state = [];
  }

  int get unreadCount => state.where((n) => n['read'] == false).length;
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<Map<String, dynamic>>>(
  (ref) => NotificationNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => n['read'] == false).length;
});
