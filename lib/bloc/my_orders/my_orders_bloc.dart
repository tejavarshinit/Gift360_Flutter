import 'package:flutter_bloc/flutter_bloc.dart';

import 'my_orders_event.dart';
import 'my_orders_state.dart';

class MyOrdersBloc extends Bloc<MyOrdersEvent, MyOrdersState> {
  MyOrdersBloc() : super(const MyOrdersState()) {
    on<MyOrdersStarted>(_onStarted);
    on<MyOrdersRefreshed>(_onRefreshed);
  }

  void _onStarted(MyOrdersStarted event, Emitter<MyOrdersState> emit) {
    emit(state.copyWith(status: MyOrdersStatus.ready, message: ''));
  }

  void _onRefreshed(MyOrdersRefreshed event, Emitter<MyOrdersState> emit) {
    emit(state.copyWith(status: MyOrdersStatus.ready, message: ''));
  }
}