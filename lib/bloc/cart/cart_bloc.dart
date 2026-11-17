import 'package:flutter_bloc/flutter_bloc.dart';

import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<CartStarted>(_onStarted);
    on<CartRefreshed>(_onRefreshed);
  }

  void _onStarted(CartStarted event, Emitter<CartState> emit) {
    emit(state.copyWith(status: CartStatus.ready, message: ''));
  }

  void _onRefreshed(CartRefreshed event, Emitter<CartState> emit) {
    emit(state.copyWith(status: CartStatus.ready, message: ''));
  }
}