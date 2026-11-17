import 'package:flutter_bloc/flutter_bloc.dart';

import 'supercoin_voucher_event.dart';
import 'supercoin_voucher_state.dart';

class SupercoinVoucherBloc extends Bloc<SupercoinVoucherEvent, SupercoinVoucherState> {
  SupercoinVoucherBloc() : super(const SupercoinVoucherState()) {
    on<SupercoinVoucherStarted>(_onStarted);
    on<SupercoinVoucherRefreshed>(_onRefreshed);
  }

  void _onStarted(SupercoinVoucherStarted event, Emitter<SupercoinVoucherState> emit) {
    emit(state.copyWith(status: SupercoinVoucherStatus.ready, message: ''));
  }

  void _onRefreshed(SupercoinVoucherRefreshed event, Emitter<SupercoinVoucherState> emit) {
    emit(state.copyWith(status: SupercoinVoucherStatus.ready, message: ''));
  }
}