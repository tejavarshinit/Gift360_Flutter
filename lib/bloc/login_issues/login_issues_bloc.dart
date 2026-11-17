import 'package:flutter_bloc/flutter_bloc.dart';

import 'login_issues_event.dart';
import 'login_issues_state.dart';

class LoginIssuesBloc extends Bloc<LoginIssuesEvent, LoginIssuesState> {
  LoginIssuesBloc() : super(const LoginIssuesState()) {
    on<LoginIssuesStarted>(_onStarted);
    on<LoginIssuesRefreshed>(_onRefreshed);
  }

  void _onStarted(LoginIssuesStarted event, Emitter<LoginIssuesState> emit) {
    emit(state.copyWith(status: LoginIssuesStatus.ready, message: ''));
  }

  void _onRefreshed(LoginIssuesRefreshed event, Emitter<LoginIssuesState> emit) {
    emit(state.copyWith(status: LoginIssuesStatus.ready, message: ''));
  }
}