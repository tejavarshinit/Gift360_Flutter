import 'package:equatable/equatable.dart';

enum NotificationsStatus { initial, loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.message = '',
  });

  final NotificationsStatus status;
  final String message;

  NotificationsState copyWith({NotificationsStatus? status, String? message}) {
    return NotificationsState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, message];
}