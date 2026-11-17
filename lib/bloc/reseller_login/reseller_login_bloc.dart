import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_login_event.dart';
import 'reseller_login_state.dart';

class ResellerLoginBloc extends Bloc<ResellerLoginEvent, ResellerLoginState> {
  ResellerLoginBloc() : super(const ResellerLoginState()) {
    on<ResellerLoginStarted>(_onStarted);
    on<ResellerLoginRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerLoginStarted event, Emitter<ResellerLoginState> emit) {
    emit(state.copyWith(status: ResellerLoginStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerLoginRefreshed event, Emitter<ResellerLoginState> emit) {
    emit(state.copyWith(status: ResellerLoginStatus.ready, message: ''));
  }
}