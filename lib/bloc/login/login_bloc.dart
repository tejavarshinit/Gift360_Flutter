import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(const LoginState()) {
    on<LoginStarted>(_onStarted);
    on<LoginRefreshed>(_onRefreshed);
  }

  void _onStarted(LoginStarted event, Emitter<LoginState> emit) {
    emit(state.copyWith(status: LoginStatus.ready, message: ''));
  }

  void _onRefreshed(LoginRefreshed event, Emitter<LoginState> emit) {
    emit(state.copyWith(status: LoginStatus.ready, message: ''));
  }
}