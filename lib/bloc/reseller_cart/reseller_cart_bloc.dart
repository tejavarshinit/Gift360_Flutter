import 'package:flutter_bloc/flutter_bloc.dart';

import 'reseller_cart_event.dart';
import 'reseller_cart_state.dart';

class ResellerCartBloc extends Bloc<ResellerCartEvent, ResellerCartState> {
  ResellerCartBloc() : super(const ResellerCartState()) {
    on<ResellerCartStarted>(_onStarted);
    on<ResellerCartRefreshed>(_onRefreshed);
  }

  void _onStarted(ResellerCartStarted event, Emitter<ResellerCartState> emit) {
    emit(state.copyWith(status: ResellerCartStatus.ready, message: ''));
  }

  void _onRefreshed(ResellerCartRefreshed event, Emitter<ResellerCartState> emit) {
    emit(state.copyWith(status: ResellerCartStatus.ready, message: ''));
  }
}