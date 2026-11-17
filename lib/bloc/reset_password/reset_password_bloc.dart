import 'package:flutter_bloc/flutter_bloc.dart';

import 'reset_password_event.dart';
import 'reset_password_state.dart';

class ResetPasswordBloc extends Bloc<ResetPasswordEvent, ResetPasswordState> {
  ResetPasswordBloc() : super(const ResetPasswordState()) {
    on<ResetPasswordStarted>(_onStarted);
    on<ResetPasswordRefreshed>(_onRefreshed);
  }

  void _onStarted(ResetPasswordStarted event, Emitter<ResetPasswordState> emit) {
    emit(state.copyWith(status: ResetPasswordStatus.ready, message: ''));
  }

  void _onRefreshed(ResetPasswordRefreshed event, Emitter<ResetPasswordState> emit) {
    emit(state.copyWith(status: ResetPasswordStatus.ready, message: ''));
  }
}