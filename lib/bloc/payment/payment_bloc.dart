import 'package:flutter_bloc/flutter_bloc.dart';

import 'payment_event.dart';
import 'payment_state.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc() : super(const PaymentState()) {
    on<PaymentStarted>(_onStarted);
    on<PaymentRefreshed>(_onRefreshed);
  }

  void _onStarted(PaymentStarted event, Emitter<PaymentState> emit) {
    emit(state.copyWith(status: PaymentStatus.ready, message: ''));
  }

  void _onRefreshed(PaymentRefreshed event, Emitter<PaymentState> emit) {
    emit(state.copyWith(status: PaymentStatus.ready, message: ''));
  }
}