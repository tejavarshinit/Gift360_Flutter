import 'package:flutter_bloc/flutter_bloc.dart';

import 'bulk_purchase_event.dart';
import 'bulk_purchase_state.dart';

class BulkPurchaseBloc extends Bloc<BulkPurchaseEvent, BulkPurchaseState> {
  BulkPurchaseBloc() : super(const BulkPurchaseState()) {
    on<BulkPurchaseStarted>(_onStarted);
    on<BulkPurchaseRefreshed>(_onRefreshed);
  }

  void _onStarted(BulkPurchaseStarted event, Emitter<BulkPurchaseState> emit) {
    emit(state.copyWith(status: BulkPurchaseStatus.ready, message: ''));
  }

  void _onRefreshed(BulkPurchaseRefreshed event, Emitter<BulkPurchaseState> emit) {
    emit(state.copyWith(status: BulkPurchaseStatus.ready, message: ''));
  }
}