import 'package:flutter_bloc/flutter_bloc.dart';

import 'order_checkout_event.dart';
import 'order_checkout_state.dart';

class OrderCheckoutBloc extends Bloc<OrderCheckoutEvent, OrderCheckoutState> {
  OrderCheckoutBloc() : super(const OrderCheckoutState()) {
    on<OrderCheckoutStarted>(_onStarted);
    on<OrderCheckoutRefreshed>(_onRefreshed);
  }

  void _onStarted(OrderCheckoutStarted event, Emitter<OrderCheckoutState> emit) {
    emit(state.copyWith(status: OrderCheckoutStatus.ready, message: ''));
  }

  void _onRefreshed(OrderCheckoutRefreshed event, Emitter<OrderCheckoutState> emit) {
    emit(state.copyWith(status: OrderCheckoutStatus.ready, message: ''));
  }
}