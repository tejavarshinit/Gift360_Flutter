import 'package:flutter_bloc/flutter_bloc.dart';

import 'forgot_password_event.dart';
import 'forgot_password_state.dart';

class ForgotPasswordBloc extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  ForgotPasswordBloc() : super(const ForgotPasswordState()) {
    on<ForgotPasswordStarted>(_onStarted);
    on<ForgotPasswordRefreshed>(_onRefreshed);
  }

  void _onStarted(ForgotPasswordStarted event, Emitter<ForgotPasswordState> emit) {
    emit(state.copyWith(status: ForgotPasswordStatus.ready, message: ''));
  }

  void _onRefreshed(ForgotPasswordRefreshed event, Emitter<ForgotPasswordState> emit) {
    emit(state.copyWith(status: ForgotPasswordStatus.ready, message: ''));
  }
}