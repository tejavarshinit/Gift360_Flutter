import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_dashboard_event.dart';
import 'reseller_dashboard_state.dart';

class ResellerDashboardBloc extends Bloc<ResellerDashboardEvent, ResellerDashboardState> {
  ResellerDashboardBloc() : super(const ResellerDashboardState()) {
    on<ResellerDashboardStarted>(_onStarted);
    on<ResellerDashboardRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerDashboardStarted event, Emitter<ResellerDashboardState> emit) {
    emit(state.copyWith(status: ResellerDashboardStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerDashboardRefreshed event, Emitter<ResellerDashboardState> emit) {
    emit(state.copyWith(status: ResellerDashboardStatus.ready, message: ''));
  }
}