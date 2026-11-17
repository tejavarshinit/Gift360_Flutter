import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_order_details_event.dart';
import 'reseller_order_details_state.dart';

class ResellerOrderDetailsBloc extends Bloc<ResellerOrderDetailsEvent, ResellerOrderDetailsState> {
  ResellerOrderDetailsBloc() : super(const ResellerOrderDetailsState()) {
    on<ResellerOrderDetailsStarted>(_onStarted);
    on<ResellerOrderDetailsRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerOrderDetailsStarted event, Emitter<ResellerOrderDetailsState> emit) {
    emit(state.copyWith(status: ResellerOrderDetailsStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerOrderDetailsRefreshed event, Emitter<ResellerOrderDetailsState> emit) {
    emit(state.copyWith(status: ResellerOrderDetailsStatus.ready, message: ''));
  }
}