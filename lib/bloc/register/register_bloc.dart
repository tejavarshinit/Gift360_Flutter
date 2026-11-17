import 'package:flutter_bloc/flutter_bloc.dart';

import 'register_event.dart';
import 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc() : super(const RegisterState()) {
    on<RegisterStarted>(_onStarted);
    on<RegisterRefreshed>(_onRefreshed);
  }

  void _onStarted(RegisterStarted event, Emitter<RegisterState> emit) {
    emit(state.copyWith(status: RegisterStatus.ready, message: ''));
  }

  void _onRefreshed(RegisterRefreshed event, Emitter<RegisterState> emit) {
    emit(state.copyWith(status: RegisterStatus.ready, message: ''));
  }
}