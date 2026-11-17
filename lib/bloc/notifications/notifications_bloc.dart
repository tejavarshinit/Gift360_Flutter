import 'package:flutter_bloc/flutter_bloc.dart';

import 'notifications_event.dart';
import 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc() : super(const NotificationsState()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsRefreshed>(_onRefreshed);
  }

  void _onStarted(NotificationsStarted event, Emitter<NotificationsState> emit) {
    emit(state.copyWith(status: NotificationsStatus.ready, message: ''));
  }

  void _onRefreshed(NotificationsRefreshed event, Emitter<NotificationsState> emit) {
    emit(state.copyWith(status: NotificationsStatus.ready, message: ''));
  }
}