import 'package:flutter_bloc/flutter_bloc.dart';

import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc() : super(const OrdersState()) {
    on<OrdersStarted>(_onStarted);
    on<OrdersRefreshed>(_onRefreshed);
  }

  void _onStarted(OrdersStarted event, Emitter<OrdersState> emit) {
    emit(state.copyWith(status: OrdersStatus.ready, message: ''));
  }

  void _onRefreshed(OrdersRefreshed event, Emitter<OrdersState> emit) {
    emit(state.copyWith(status: OrdersStatus.ready, message: ''));
  }
}