import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_reset_password_event.dart';
import 'reseller_reset_password_state.dart';

class ResellerResetPasswordBloc extends Bloc<ResellerResetPasswordEvent, ResellerResetPasswordState> {
  ResellerResetPasswordBloc() : super(const ResellerResetPasswordState()) {
    on<ResellerResetPasswordStarted>(_onStarted);
    on<ResellerResetPasswordRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerResetPasswordStarted event, Emitter<ResellerResetPasswordState> emit) {
    emit(state.copyWith(status: ResellerResetPasswordStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerResetPasswordRefreshed event, Emitter<ResellerResetPasswordState> emit) {
    emit(state.copyWith(status: ResellerResetPasswordStatus.ready, message: ''));
  }
}